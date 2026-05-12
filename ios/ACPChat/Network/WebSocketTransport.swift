//
//  WebSocketTransport.swift
//
//  Plain URLSessionWebSocketTask wrapper with:
//    - text-only framing (we reject binary frames on the server too)
//    - ping-pong heartbeat (server pings every 30s; we answer automatically;
//      we also ping proactively to detect dead upstream)
//    - reconnect-on-demand (caller decides: the transport just exposes
//      `connect()` / `disconnect()` and a pair of send/recv streams)
//    - bearer-token auth via Sec-WebSocket-Protocol (URL query also works
//      on the server, but keeping auth out of the URL makes logs cleaner)
//

import Foundation

actor WebSocketTransport {
    struct Config: Sendable {
        /// Full wss://host/acp URL. Token goes in `token`, not here.
        /// For Cloudflare Tunnel: wss://acp.example.com/acp
        /// (CF terminates TLS on edge → bridge may run plain ws:// on 127.0.0.1).
        let url: URL
        /// Shared-secret token configured on the bridge (ACP_WS_TOKEN).
        let token: String
        /// For self-signed TLS over Tailscale/LAN: true to accept the cert.
        /// With Cloudflare Tunnel you get a real cert — keep this false.
        let allowSelfSignedTLS: Bool
        /// Cloudflare Access service token (optional). When set, the WS handshake
        /// carries `CF-Access-Client-Id` + `CF-Access-Client-Secret` headers so
        /// the CF edge lets the connection reach the tunnel origin.
        /// Create at: Zero Trust → Access → Service Tokens.
        let cfAccessClientId: String?
        let cfAccessClientSecret: String?

        init(
            url: URL,
            token: String,
            allowSelfSignedTLS: Bool = false,
            cfAccessClientId: String? = nil,
            cfAccessClientSecret: String? = nil
        ) {
            self.url = url
            self.token = token
            self.allowSelfSignedTLS = allowSelfSignedTLS
            self.cfAccessClientId = cfAccessClientId
            self.cfAccessClientSecret = cfAccessClientSecret
        }
    }

    enum State: Sendable, Equatable {
        case idle
        case connecting
        case connected
        case disconnected(reason: String)
    }

    private let config: Config
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private(set) var state: State = .idle
    private var stateContinuation: AsyncStream<State>.Continuation?
    private var frameContinuation: AsyncStream<Data>.Continuation?
    /// Resolved by didOpenWithProtocol (success) or didCompleteWithError
    /// / didCloseWith (failure). Allows `connect()` to actually wait for
    /// the WebSocket handshake to finish — URLSessionWebSocketTask.resume()
    /// does NOT block on handshake, it just kicks off the network task.
    private var openContinuation: CheckedContinuation<Void, Error>?

    /// Observe connection state changes.
    let stateStream: AsyncStream<State>
    /// Inbound NDJSON text frames. Each element is one JSON-RPC message.
    let frameStream: AsyncStream<Data>

    init(config: Config) {
        self.config = config
        var stateCont: AsyncStream<State>.Continuation!
        self.stateStream = AsyncStream { stateCont = $0 }
        var frameCont: AsyncStream<Data>.Continuation!
        self.frameStream = AsyncStream { frameCont = $0 }
        self.stateContinuation = stateCont
        self.frameContinuation = frameCont
    }

    func connect() async throws {
        disconnect(reason: "reconnect")
        transitionTo(.connecting)

        // Delegate callbacks hop back into our actor via Task { await ... }.
        // `weak self` avoids a retain cycle URLSession → delegate → actor.
        let delegate = WSDelegate(
            allowSelfSignedTLS: config.allowSelfSignedTLS,
            onOpen: { [weak self] in
                Task { await self?.handleDidOpen() }
            },
            onClose: { [weak self] reason in
                Task { await self?.handleDidClose(reason: reason) }
            }
        )
        let session = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        self.session = session

        var req = URLRequest(url: config.url)
        req.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        // Cloudflare Access service token (if configured). These headers travel
        // through the TLS tunnel and are consumed by the CF edge, never by the
        // origin bridge. Safe to attach always; if absent, standard bearer flow.
        if let cfId = config.cfAccessClientId, !cfId.isEmpty {
            req.setValue(cfId, forHTTPHeaderField: "CF-Access-Client-Id")
        }
        if let cfSecret = config.cfAccessClientSecret, !cfSecret.isEmpty {
            req.setValue(cfSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
        // 10s handshake budget. If the TCP/TLS/WS handshake hasn't finished
        // in 10s, we fail fast — user sees a clear error, not a silent fake
        // "online". iOS default timeoutInterval is 60s which is too long.
        req.timeoutInterval = 10

        let task = session.webSocketTask(with: req)
        self.task = task

        // Wait for delegate to fire didOpen / didClose. Also race against
        // a hard timeout so we don't hang forever if the edge never replies
        // (common with DPI or wrong port).
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    Task { [weak self] in
                        await self?.setOpenContinuation(cont)
                        // resume AFTER the continuation is registered, otherwise
                        // a fast delegate callback could fire with no listener.
                        await self?.resumeTask()
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(12))
                throw NSError(
                    domain: "acp", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "handshake timeout"]
                )
            }
            // Whichever finishes first wins; cancel the other.
            try await group.next()
            group.cancelAll()
        }

        transitionTo(.connected)
        Task { await pumpReceive() }
        Task { await pumpPing() }
    }

    private func setOpenContinuation(_ cont: CheckedContinuation<Void, Error>) {
        self.openContinuation = cont
    }

    private func resumeTask() {
        self.task?.resume()
    }

    private func handleDidOpen() {
        openContinuation?.resume(returning: ())
        openContinuation = nil
    }

    private func handleDidClose(reason: String) {
        // If we were still waiting on handshake, that's a failure.
        openContinuation?.resume(throwing: NSError(
            domain: "acp", code: -3,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
        openContinuation = nil
        transitionTo(.disconnected(reason: reason))
    }

    func disconnect(reason: String = "client") {
        task?.cancel(with: .goingAway, reason: reason.data(using: .utf8))
        task = nil
        session?.invalidateAndCancel()
        session = nil
        if case .connected = state { transitionTo(.disconnected(reason: reason)) }
        if case .connecting = state { transitionTo(.disconnected(reason: reason)) }
    }

    /// Send one JSON-RPC message (already serialized).
    func send(_ data: Data) async throws {
        guard let task else { throw NSError(
            domain: "acp", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Not connected"]
        )}
        // Server enforces text frames. Swift side: send as .string.
        let text = String(data: data, encoding: .utf8) ?? ""
        try await task.send(.string(text))
    }

    // ───────────── private ─────────────

    private func transitionTo(_ next: State) {
        state = next
        stateContinuation?.yield(next)
    }

    /// Long-running receive loop. URLSessionWebSocketTask.receive() returns
    /// one message at a time, so we loop until an error (typically the
    /// connection close) surfaces.
    private func pumpReceive() async {
        guard let task else { return }
        while true {
            do {
                let msg = try await task.receive()
                switch msg {
                case .string(let s):
                    if let data = s.data(using: .utf8) {
                        frameContinuation?.yield(data)
                    }
                case .data(let d):
                    // Server shouldn't send binary; accept defensively.
                    frameContinuation?.yield(d)
                @unknown default:
                    break
                }
            } catch {
                transitionTo(.disconnected(reason: "recv \(error.localizedDescription)"))
                return
            }
        }
    }

    /// Send a ping every 25s. The server has its own 30s ping timer, so
    /// pairs of pings keep NAT state warm on cellular.
    private func pumpPing() async {
        while state == .connected {
            try? await Task.sleep(for: .seconds(25))
            guard let task else { return }
            await withCheckedContinuation { cont in
                task.sendPing { _ in cont.resume() }
            }
        }
    }
}

/// URLSession delegate combining:
///   - optional self-signed TLS bypass (only for Tailscale/LAN trust zones),
///   - didOpenWithProtocol / didCloseWith / didCompleteWithError callbacks
///     so the actor can finally know when the WS handshake has actually
///     completed (URLSessionWebSocketTask.resume() does NOT block on it).
private final class WSDelegate: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate, URLSessionTaskDelegate {
    let allowSelfSignedTLS: Bool
    let onOpen: @Sendable () -> Void
    let onClose: @Sendable (String) -> Void
    /// Fires at most once per connect cycle.
    private var fired = false
    private let lock = NSLock()

    init(
        allowSelfSignedTLS: Bool,
        onOpen: @escaping @Sendable () -> Void,
        onClose: @escaping @Sendable (String) -> Void
    ) {
        self.allowSelfSignedTLS = allowSelfSignedTLS
        self.onOpen = onOpen
        self.onClose = onClose
    }

    private func fireOnce(_ block: () -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard !fired else { return }
        fired = true
        block()
    }

    // MARK: - TLS

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if allowSelfSignedTLS,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - WebSocket lifecycle

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocolStr: String?
    ) {
        fireOnce { onOpen() }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) }
            ?? "closed (code=\(closeCode.rawValue))"
        fireOnce { onClose(reasonStr) }
    }

    // MARK: - Task-level errors (handshake failed before WS open)

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            fireOnce { onClose(error.localizedDescription) }
        } else {
            // Task completed cleanly without ever opening — treat as close.
            fireOnce { onClose("task completed without open") }
        }
    }
}
