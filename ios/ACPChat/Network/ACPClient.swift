//
//  ACPClient.swift
//
//  High-level ACP (Agent Client Protocol) client. Sits on top of
//  WebSocketTransport + JSONRPC and exposes the narrow surface the
//  chat UI actually needs:
//
//    await client.connect(config)
//    let sid = try await client.newSession(cwd: "/home/user")
//    try await client.prompt(sessionId: sid, text: "...") { event in ... }
//
//  Server → client requests (`session/request_permission`,
//  `fs/read_text_file`, `fs/write_text_file`, `terminal/create`) are
//  delivered through `handlers` — the view layer binds UI to them.
//

import Foundation
import Observation

@Observable
@MainActor
final class ACPClient {
    enum ConnectionStatus: Equatable {
        case idle
        case connecting
        case connected
        case error(String)
        case disconnected(reason: String)
    }

    var status: ConnectionStatus = .idle

    /// Callbacks the UI wires up. Nil → we auto-reject with a canned error.
    /// These run on MainActor so they can touch SwiftData / UI state.
    var onRequestPermission: ((PermissionRequest) async -> PermissionOutcome)?
    var onReadTextFile: ((String) async -> String?)?
    var onWriteTextFile: ((String, String) async -> Bool)?

    /// Per-session stream continuation. Keyed by ACP session id so that
    /// simultaneous prompts in different sessions don't step on each other.
    private var sessionUpdateContinuations: [String: AsyncStream<SessionEvent>.Continuation] = [:]

    private var transport: WebSocketTransport?
    private var pendingRequests: [Int64: CheckedContinuation<AnyCodable, Error>] = [:]
    private var nextRequestId: Int64 = 1

    // MARK: - Public API

    func connect(_ config: WebSocketTransport.Config) async throws {
        status = .connecting
        let t = WebSocketTransport(config: config)
        self.transport = t
        // transport.connect() now waits for real WS handshake (didOpenWithProtocol)
        // and throws on handshake failure or 10s timeout. Without `try` the UI
        // used to get a fake "online" when the socket was actually dead.
        do {
            try await t.connect()
        } catch {
            status = .error(error.localizedDescription)
            transport = nil
            throw error
        }
        status = .connected
        Task { await pumpFrames(from: t) }
        Task { await pumpState(from: t) }
        do {
            try await initialize()
        } catch {
            // Handshake ok but protocol handshake failed — surface it clearly
            // instead of leaving status=connected with dead RPC state.
            status = .error("initialize: \(error.localizedDescription)")
            await t.disconnect(reason: "init failed")
            transport = nil
            throw error
        }
    }

    func disconnect() async {
        await transport?.disconnect(reason: "user")
        transport = nil
        status = .disconnected(reason: "user")
    }

    /// Create a new ACP session. Returns routerSessionId.
    func newSession(cwd: String, mcpServers: [AnyCodable] = []) async throws -> String {
        let params: AnyCodable = .object([
            "cwd": .string(cwd),
            "mcpServers": .array(mcpServers),
        ])
        let result = try await request(method: "session/new", params: params)
        guard case .object(let dict) = result, case .string(let sid) = dict["sessionId"] ?? .null else {
            throw ACPError.malformed("session/new: missing sessionId")
        }
        return sid
    }

    /// Reconnect an existing router session after app relaunch.
    func loadSession(routerSessionId: String, cwd: String) async throws {
        let params: AnyCodable = .object([
            "sessionId": .string(routerSessionId),
            "cwd": .string(cwd),
            "mcpServers": .array([]),
        ])
        _ = try await request(method: "session/load", params: params)
    }

    /// Send a prompt to an active session. Returns an async stream of
    /// SessionEvents (token deltas, role changes, tool calls). The stream
    /// finishes when the router returns the `session/prompt` response.
    func prompt(
        sessionId: String,
        text: String
    ) async throws -> AsyncStream<SessionEvent> {
        let stream = AsyncStream<SessionEvent> { cont in
            sessionUpdateContinuations[sessionId] = cont
        }
        let params: AnyCodable = .object([
            "sessionId": .string(sessionId),
            "prompt": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(text),
                ])
            ]),
        ])
        Task {
            do {
                _ = try await request(method: "session/prompt", params: params)
            } catch {
                sessionUpdateContinuations[sessionId]?.yield(.error(error.localizedDescription))
            }
            sessionUpdateContinuations[sessionId]?.finish()
            sessionUpdateContinuations[sessionId] = nil
        }
        return stream
    }

    func cancel(sessionId: String) async {
        let params: AnyCodable = .object(["sessionId": .string(sessionId)])
        _ = try? await request(method: "session/cancel", params: params)
    }

    // MARK: - Bridge-local custom methods (router-side persisted sessions, fs)

    /// Fetch router-side persisted sessions (from router's data/sessions.json).
    /// These are sessions that survive between connects — we can resurrect
    /// them via `loadSession(routerSessionId:cwd:)`.
    func listRouterSessions() async throws -> [PersistedRouterSession] {
        let result = try await request(method: "router/listPersistedSessions", params: nil)
        guard case .object(let dict) = result,
              case .array(let arr) = dict["sessions"] ?? .null
        else {
            throw ACPError.malformed("router/listPersistedSessions: missing sessions array")
        }
        return arr.compactMap { any -> PersistedRouterSession? in
            guard case .object(let e) = any else { return nil }
            return PersistedRouterSession(
                routerSessionId: e["routerSessionId"]?.stringValue ?? "",
                agentId: e["agentId"]?.stringValue ?? "",
                currentModel: e["currentModel"]?.stringValue ?? "",
                cwd: e["cwd"]?.stringValue,
                savedAt: e["savedAt"]?.doubleValue ?? 0
            )
        }.filter { !$0.routerSessionId.isEmpty }
    }

    /// List entries of a directory through the bridge (allowlist-checked).
    func fsList(path: String) async throws -> FSListResult {
        let params: AnyCodable = .object(["path": .string(path)])
        let result = try await request(method: "fs/list", params: params)
        guard case .object(let dict) = result,
              case .string(let resolved) = dict["path"] ?? .null,
              case .array(let arr) = dict["entries"] ?? .null
        else {
            throw ACPError.malformed("fs/list: malformed result")
        }
        let entries: [FSEntry] = arr.compactMap { any in
            guard case .object(let e) = any else { return nil }
            return FSEntry(
                name: e["name"]?.stringValue ?? "",
                path: e["path"]?.stringValue ?? "",
                isDir: e["isDir"]?.boolValue ?? false,
                size: Int64(e["size"]?.doubleValue ?? 0),
                mtime: e["mtime"]?.doubleValue ?? 0
            )
        }
        return FSListResult(path: resolved, entries: entries)
    }

    /// Execute a router `chat …` CLI command through the bridge.
    ///
    /// Мобильный клиент НЕ держит локальной копии chat.ts (там весь
    /// multi-agent orchestrator: ask / round / ensemble / poll / auto /
    /// debate). Bridge спаунит `node dist/cli/chat.js <argv>` и возвращает
    /// stdout/stderr/exitCode. Ранее пользователь видел, что агенты
    /// «молчат» — это было потому, что `chat ask codestral …` летел в
    /// session/prompt как обычный текст для Claude, и Claude их игнорировал.
    ///
    /// - Parameters:
    ///   - argv: верхнеуровневая команда и аргументы, напр. ["ask",
    ///     "codestral", "disasm this function"]. Bridge валидирует первый
    ///     токен против белого списка (см. CHAT_ALLOWED_VERBS).
    ///   - stdin: опциональный stdin (используется, напр., `chat paste`).
    func chatExec(argv: [String], stdin: String? = nil) async throws -> ChatExecResult {
        var obj: [String: AnyCodable] = [
            "argv": .array(argv.map { .string($0) }),
        ]
        if let stdin, !stdin.isEmpty { obj["stdin"] = .string(stdin) }
        let result = try await request(method: "chat/exec", params: .object(obj))
        guard case .object(let dict) = result else {
            throw ACPError.malformed("chat/exec: not an object")
        }
        let stdout = dict["stdout"]?.stringValue ?? ""
        let stderr = dict["stderr"]?.stringValue ?? ""
        // exitCode может быть null если процесс убит сигналом — проваливаемся в -1.
        let exitCode: Int
        if case .int(let v)? = dict["exitCode"] {
            exitCode = Int(v)
        } else if case .double(let v)? = dict["exitCode"] {
            exitCode = Int(v)
        } else {
            exitCode = -1
        }
        return ChatExecResult(stdout: stdout, stderr: stderr, exitCode: exitCode)
    }

    /// Read a text file through the bridge (size-limited, allowlist-checked).
    func fsRead(path: String, maxBytes: Int? = nil) async throws -> FSReadResult {
        var obj: [String: AnyCodable] = ["path": .string(path)]
        if let maxBytes { obj["maxBytes"] = .int(Int64(maxBytes)) }
        let result = try await request(method: "fs/read", params: .object(obj))
        guard case .object(let dict) = result,
              case .string(let resolved) = dict["path"] ?? .null,
              case .string(let content) = dict["content"] ?? .null
        else {
            throw ACPError.malformed("fs/read: malformed result")
        }
        return FSReadResult(
            path: resolved,
            size: Int64(dict["size"]?.doubleValue ?? 0),
            mtime: dict["mtime"]?.doubleValue ?? 0,
            content: content
        )
    }

    // MARK: - Internals

    private func initialize() async throws {
        let params: AnyCodable = .object([
            "protocolVersion": .int(1),
            "clientCapabilities": .object([
                "fs": .object([
                    "readTextFile": .bool(false),
                    "writeTextFile": .bool(false),
                ]),
                "terminal": .bool(false),
            ]),
        ])
        _ = try await request(method: "initialize", params: params)
    }

    @discardableResult
    private func request(method: String, params: AnyCodable?) async throws -> AnyCodable {
        guard let transport else { throw ACPError.notConnected }
        let id = nextRequestId
        nextRequestId += 1
        let envelope = JSONRPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(envelope)
        return try await withCheckedThrowingContinuation { cont in
            pendingRequests[id] = cont
            Task {
                do { try await transport.send(data) }
                catch {
                    pendingRequests.removeValue(forKey: id)
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func reply(id: Int64, result: AnyCodable) async {
        guard let transport else { return }
        let env = JSONRPCResultReply(id: id, result: result)
        if let data = try? JSONEncoder().encode(env) {
            try? await transport.send(data)
        }
    }

    private func replyError(id: Int64, code: Int, message: String) async {
        guard let transport else { return }
        let env = JSONRPCErrorReply(
            id: id,
            error: JSONRPCError(code: code, message: message, data: nil)
        )
        if let data = try? JSONEncoder().encode(env) {
            try? await transport.send(data)
        }
    }

    private func pumpState(from t: WebSocketTransport) async {
        for await newState in t.stateStream {
            switch newState {
            case .connected:       status = .connected
            case .connecting:      status = .connecting
            case .idle:            status = .idle
            case .disconnected(let reason): status = .disconnected(reason: reason)
            }
        }
    }

    private func pumpFrames(from t: WebSocketTransport) async {
        for await data in t.frameStream {
            do {
                let msg = try JSONRPCIncoming.decode(data)
                await dispatch(msg)
            } catch {
                // Malformed frame — log and continue. Ignoring is safer than
                // reconnecting because a broken frame might be a transient
                // serializer bug; we don't want reconnect storms.
                print("ACP decode error: \(error)")
            }
        }
    }

    private func dispatch(_ msg: JSONRPCIncoming) async {
        switch msg {
        case .response(let r):
            guard let id = r.id, let cont = pendingRequests.removeValue(forKey: id) else {
                return
            }
            if let err = r.error { cont.resume(throwing: err) }
            else { cont.resume(returning: r.result ?? .null) }

        case .notification(let method, let params):
            await handleNotification(method: method, params: params)

        case .request(let id, let method, let params):
            await handleServerRequest(id: id, method: method, params: params)
        }
    }

    private func handleNotification(method: String, params: AnyCodable?) async {
        guard method == "session/update" else { return }
        guard case .object(let dict)? = params,
              case .string(let sid)? = dict["sessionId"],
              let cont = sessionUpdateContinuations[sid]
        else { return }

        guard case .object(let update)? = dict["update"] else { return }
        // ACP update variants: agent_message_chunk, agent_thought_chunk,
        // tool_call, tool_call_update, plan, available_commands_update.
        let kind = update["sessionUpdate"]?.stringValue ?? ""
        switch kind {
        case "agent_message_chunk":
            if case .object(let content)? = update["content"],
               let text = content["text"]?.stringValue {
                cont.yield(.textDelta(text))
            }
        case "agent_thought_chunk":
            if case .object(let content)? = update["content"],
               let text = content["text"]?.stringValue {
                cont.yield(.thinkingDelta(text))
            }
        case "tool_call":
            cont.yield(.toolCall(AnyCodable.object(update)))
        case "tool_call_update":
            cont.yield(.toolCallUpdate(AnyCodable.object(update)))
        case "plan":
            cont.yield(.plan(AnyCodable.object(update)))
        default:
            // Unknown event — pass raw so UI can log it.
            cont.yield(.raw(AnyCodable.object(update)))
        }
    }

    private func handleServerRequest(id: Int64, method: String, params: AnyCodable?) async {
        switch method {
        case "session/request_permission":
            let outcome: PermissionOutcome
            if let handler = onRequestPermission,
               case .object(let dict)? = params {
                let req = PermissionRequest(raw: .object(dict))
                outcome = await handler(req)
            } else {
                outcome = .reject(reason: "no handler")
            }
            await reply(id: id, result: .object([
                "outcome": .object([
                    "outcome": .string(outcome.kind),
                ]),
            ]))

        case "fs/read_text_file":
            if let handler = onReadTextFile,
               case .object(let dict)? = params,
               case .string(let path)? = dict["path"],
               let content = await handler(path) {
                await reply(id: id, result: .object(["content": .string(content)]))
            } else {
                await replyError(id: id, code: -32000, message: "file not available")
            }

        case "fs/write_text_file":
            if let handler = onWriteTextFile,
               case .object(let dict)? = params,
               case .string(let path)? = dict["path"],
               case .string(let content)? = dict["content"],
               await handler(path, content) == true {
                await reply(id: id, result: .null)
            } else {
                await replyError(id: id, code: -32000, message: "write not available")
            }

        default:
            // Anything we don't know: fail loudly rather than silently
            // succeeding — the agent will treat it as an unrecoverable
            // error and back off, which is the correct behavior for a
            // thin client.
            await replyError(id: id, code: -32601, message: "method not found: \(method)")
        }
    }
}

// MARK: - Value types

enum ACPError: LocalizedError {
    case notConnected
    case malformed(String)
    var errorDescription: String? {
        switch self {
        case .notConnected:       return "Not connected to router"
        case .malformed(let m):   return "Malformed response: \(m)"
        }
    }
}

enum SessionEvent: Sendable {
    case textDelta(String)
    case thinkingDelta(String)
    case toolCall(AnyCodable)
    case toolCallUpdate(AnyCodable)
    case plan(AnyCodable)
    case error(String)
    case raw(AnyCodable)
}

struct PermissionRequest {
    let raw: AnyCodable
    var toolCallSummary: String {
        raw["toolCall", "title"]?.stringValue
            ?? raw["toolCall", "kind"]?.stringValue
            ?? "tool call"
    }
}

struct PersistedRouterSession: Identifiable, Hashable, Sendable {
    var id: String { routerSessionId }
    let routerSessionId: String
    let agentId: String
    let currentModel: String
    let cwd: String?
    let savedAt: Double
}

struct FSEntry: Identifiable, Hashable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let isDir: Bool
    let size: Int64
    let mtime: Double
}

struct FSListResult: Sendable {
    let path: String
    let entries: [FSEntry]
}

struct FSReadResult: Sendable {
    let path: String
    let size: Int64
    let mtime: Double
    let content: String
}

/// Result of a `chat/exec` RPC call (router CLI invocation via bridge).
struct ChatExecResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int
    /// Удобный синтетический флаг для UI. exitCode == 0 → успех.
    var isSuccess: Bool { exitCode == 0 }
    /// Компактное строковое представление для bubble'а: если exit != 0 или
    /// есть stderr, подклеиваем его к stdout с префиксом — чтобы пользователь
    /// сразу видел, что сломалось, а не гадал о молчащем пузырьке.
    var displayText: String {
        var out = stdout
        if !stderr.isEmpty {
            if !out.isEmpty { out += "\n\n" }
            out += "── stderr ──\n" + stderr
        }
        if exitCode != 0 {
            if !out.isEmpty { out += "\n\n" }
            out += "exit: \(exitCode)"
        }
        return out.isEmpty ? "(no output)" : out
    }
}

enum PermissionOutcome {
    case allow
    case allowAlways
    case reject(reason: String)

    var kind: String {
        switch self {
        case .allow:        return "selected"
        case .allowAlways:  return "selected"
        case .reject:       return "cancelled"
        }
    }
}
