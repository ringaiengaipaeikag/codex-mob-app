//
//  StoredSession.swift
//
//  SwiftData model for a chat session. Mirrors an acp-router
//  routerSessionId + metadata so the iOS app can reconnect to an
//  existing session after relaunch (the router's restoreSessions()
//  on startup keeps that id alive).
//

import Foundation
import SwiftData

@Model
final class StoredSession {
    /// routerSessionId returned by acp-router's newSession. The bridge
    /// spawns one router per WS connection, so this id is stable per
    /// device + per bridge instance. After router restart, lazy-revive
    /// on the server side keeps the same id alive.
    @Attribute(.unique) var id: String

    /// Human-readable tag — set via SessionListView (e.g. "dg-opcode-42").
    /// Not sent to the router; purely local bookkeeping.
    var tag: String

    /// Timestamp of the last prompt sent OR last assistant update.
    /// Used to sort the session list.
    var updatedAt: Date

    /// Timestamp of creation. Immutable once set.
    var createdAt: Date

    /// Current mode: "default" or "dg" (DroidGuard). Mirrors
    /// `chat mode` state from the CLI. Controls what preamble the
    /// router injects on each turn.
    var mode: String

    /// Back-reference to all messages in this session. Cascade-delete:
    /// removing a session wipes its transcript too.
    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.session)
    var messages: [StoredMessage] = []

    init(id: String, tag: String, mode: String = "default") {
        self.id = id
        self.tag = tag
        self.mode = mode
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
