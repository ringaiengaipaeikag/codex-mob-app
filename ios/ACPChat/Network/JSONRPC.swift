//
//  JSONRPC.swift
//
//  Minimal JSON-RPC 2.0 envelope for ACP. The SDK on the server side
//  (@agentclientprotocol/sdk) follows strict 2.0 semantics: request
//  ids are strings or numbers; responses carry either `result` or
//  `error`; notifications (server → client push) have no id.
//
//  We use `AnyCodable` to carry arbitrary params/results without
//  re-declaring the entire ACP schema in Swift. Concrete decoders
//  (e.g. SessionUpdate) live next to this file.
//

import Foundation

/// Typed wrapper for heterogeneous JSON values. ACP params are
/// sometimes deeply nested (content blocks in a prompt request,
/// tool-call structures) — encoding the full schema in Swift is
/// cost-ineffective; we decode narrow slices only when we need them.
enum AnyCodable: Codable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int64.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyCodable].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyCodable].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "Unsupported JSON value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:            try c.encodeNil()
        case .bool(let v):     try c.encode(v)
        case .int(let v):      try c.encode(v)
        case .double(let v):   try c.encode(v)
        case .string(let v):   try c.encode(v)
        case .array(let v):    try c.encode(v)
        case .object(let v):   try c.encode(v)
        }
    }

    /// Convenience: walk a path like `["params", "prompt"]`.
    subscript(path: String...) -> AnyCodable? {
        var cur: AnyCodable = self
        for key in path {
            guard case .object(let dict) = cur, let v = dict[key] else { return nil }
            cur = v
        }
        return cur
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    /// Numeric coercion — accepts int or double JSON values. Handy for
    /// mtime / size fields where server encodings drift between types.
    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v):    return Double(v)
        default:             return nil
        }
    }

    var intValue: Int64? {
        switch self {
        case .int(let v):    return v
        case .double(let v): return Int64(v)
        default:             return nil
        }
    }
}

/// A JSON-RPC 2.0 request sent from client to server.
struct JSONRPCRequest: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int64
    let method: String
    let params: AnyCodable?
}

/// A JSON-RPC 2.0 notification (no id).
struct JSONRPCNotification: Encodable {
    let jsonrpc: String = "2.0"
    let method: String
    let params: AnyCodable?
}

/// A JSON-RPC 2.0 response from the server.
struct JSONRPCResponse: Decodable {
    let jsonrpc: String
    let id: Int64?
    let result: AnyCodable?
    let error: JSONRPCError?
}

struct JSONRPCError: Decodable, Error, LocalizedError {
    let code: Int
    let message: String
    let data: AnyCodable?

    /// Прокидываем реальное `message` сервера в `error.localizedDescription`.
    /// Без этого Swift возвращает generic «The operation couldn't be
    /// completed. (ACPChat.JSONRPCError error 1.)» и в UI не видно,
    /// почему именно router отклонил запрос (напр. `path outside allowed
    /// roots` или `fs/list: ENOENT: no such file or directory`).
    var errorDescription: String? { "[\(code)] \(message)" }
}

/// Generic inbound envelope. Exactly one of: {request, response, notification}.
enum JSONRPCIncoming {
    case response(JSONRPCResponse)
    /// Server → client request (e.g. requestPermission, readTextFile).
    case request(id: Int64, method: String, params: AnyCodable?)
    case notification(method: String, params: AnyCodable?)

    static func decode(_ data: Data) throws -> JSONRPCIncoming {
        let obj = try JSONDecoder().decode(AnyCodable.self, from: data)
        guard case .object(let dict) = obj else {
            throw JSONRPCError(code: -32600, message: "Not an object", data: nil)
        }
        let hasId = dict["id"] != nil && {
            if case .null = dict["id"]! { return false }
            return true
        }()
        let hasMethod = dict["method"] != nil
        let hasResult = dict["result"] != nil
        let hasError = dict["error"] != nil

        // Response: has id, has result or error, no method.
        if hasId && !hasMethod && (hasResult || hasError) {
            return .response(try JSONDecoder().decode(JSONRPCResponse.self, from: data))
        }
        // Request: has id AND method.
        if hasId && hasMethod {
            guard case .int(let reqId) = dict["id"]! else {
                throw JSONRPCError(code: -32600, message: "Non-integer id", data: nil)
            }
            guard case .string(let method) = dict["method"]! else {
                throw JSONRPCError(code: -32600, message: "Non-string method", data: nil)
            }
            return .request(id: reqId, method: method, params: dict["params"])
        }
        // Notification: has method, no id.
        if hasMethod {
            guard case .string(let method) = dict["method"]! else {
                throw JSONRPCError(code: -32600, message: "Non-string method", data: nil)
            }
            return .notification(method: method, params: dict["params"])
        }
        throw JSONRPCError(code: -32600, message: "Invalid envelope", data: nil)
    }
}

/// Server → client request response that we send back.
struct JSONRPCResultReply: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int64
    let result: AnyCodable
}

struct JSONRPCErrorReply: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int64
    let error: JSONRPCError

    enum CodingKeys: String, CodingKey { case jsonrpc, id, error }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(jsonrpc, forKey: .jsonrpc)
        try c.encode(id, forKey: .id)
        // JSONRPCError is Decodable-only; re-encode manually.
        var ec = c.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        try ec.encode(error.code, forKey: .code)
        try ec.encode(error.message, forKey: .message)
        if let d = error.data { try ec.encode(d, forKey: .data) }
    }

    private enum ErrorKeys: String, CodingKey { case code, message, data }
}
