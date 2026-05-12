//
//  StoredMessage.swift
//
//  SwiftData model for a single message within a session.
//  Accommodates the DG multi-speaker case: one turn can be authored
//  by `@codestral`, the next by `@magistral`, etc. The `speaker`
//  alias maps to an entry in the Speaker.registry table.
//

import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user      // Human-typed input from the iPhone
    case assistant // Any LLM response (role identified by `speaker`)
    case system    // Meta event: status, error, tool call, permission
}

@Model
final class StoredMessage {
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    /// Speaker alias as known by acp-router (e.g. "codestral", "opus",
    /// "devstral"). Nil for user messages and unknown/system messages.
    var speaker: String?
    /// Raw text as produced by the assistant, including [TURN → ...]
    /// marker. Renderer strips the marker into a footer chip.
    var text: String
    /// Monotonic timestamp for correct ordering. Same session, stable
    /// order even if clock jumps (we compare `createdAt` only).
    var createdAt: Date
    /// Whether streaming is still in progress for this message. Set
    /// true on the first `sessionUpdate` delta, false when the
    /// prompt request completes.
    var isStreaming: Bool
    /// Optional tool-call receipt in JSON form. For a DG agent that
    /// the router decorates with tool permissions, this is where the
    /// request stays after user's Allow/Deny.
    var toolCallJSON: String?
    /// Optional binary attachment (e.g. a screenshot) picked via
    /// PhotosPicker before send. Rendered as a thumbnail inside the
    /// bubble. Not transmitted to the bridge yet — ACP spec needs
    /// `ContentBlock.image { data, mimeType }` wiring — tracked for
    /// next iteration. Keeping it local-only preserves backward
    /// compatibility on SwiftData migration (nil default).
    var attachmentData: Data?

    @Relationship var session: StoredSession?

    init(
        role: MessageRole,
        speaker: String? = nil,
        text: String = "",
        isStreaming: Bool = false,
        attachmentData: Data? = nil,
        session: StoredSession? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.speaker = speaker
        self.text = text
        self.createdAt = Date()
        self.isStreaming = isStreaming
        self.attachmentData = attachmentData
        self.session = session
    }
}
