//
//  Speaker.swift
//
//  Mirror of config/droidguard.json → speakerToRole, so the iOS app
//  can render a "who is talking" chip with color + role label without
//  going to the network. Keep this in sync when you edit the backend
//  config.
//

import SwiftUI

struct Speaker: Identifiable, Hashable {
    /// Alias used by `chat ask`/router logs: "codestral", "opus", etc.
    let id: String
    let displayName: String
    let roleLabel: String
    /// UI tint for the speaker chip and bubble accent. Chosen to be
    /// distinguishable on both light and dark backgrounds.
    let tint: Color
}

enum SpeakerRegistry {
    /// Canonical list, ordered roughly by role weight. Add/remove
    /// entries here if you change the ensemble in config/droidguard.json.
    static let all: [Speaker] = [
        Speaker(id: "opus",      displayName: "Claude Opus 4.7",   roleLabel: "Senior Reasoner",           tint: .purple),
        Speaker(id: "sonnet",    displayName: "Claude Sonnet 4.6", roleLabel: "Peer Reasoner",             tint: .indigo),
        Speaker(id: "codestral", displayName: "Codestral",         roleLabel: "Static Analysis",           tint: .blue),
        Speaker(id: "devstral",  displayName: "Devstral-Medium",   roleLabel: "Implementation Engineer",   tint: .teal),
        Speaker(id: "magistral", displayName: "Magistral-Medium",  roleLabel: "Reasoning / Hypothesis",    tint: .orange),
        Speaker(id: "mistral",   displayName: "Mistral-Small",     roleLabel: "Sanity Checker",            tint: .yellow),
        Speaker(id: "scout",     displayName: "Llama-4-Scout",     roleLabel: "Large Context Reader",      tint: .green),
        Speaker(id: "gptoss",    displayName: "gpt-oss-120b",      roleLabel: "Stand-by",                  tint: .gray),
        Speaker(id: "groqwen",   displayName: "Qwen3-32B",         roleLabel: "Stand-by",                  tint: .gray),
        Speaker(id: "llama70",   displayName: "Llama-3.3-70B",     roleLabel: "Stand-by",                  tint: .gray),
    ]

    private static let byId: [String: Speaker] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    /// O(1) lookup. Unknown alias → a neutral fallback so the UI never
    /// crashes if the backend adds a new speaker before we update.
    static func lookup(_ alias: String?) -> Speaker {
        guard let alias, let hit = byId[alias] else {
            return Speaker(
                id: alias ?? "unknown",
                displayName: alias ?? "Assistant",
                roleLabel: "",
                tint: .secondary
            )
        }
        return hit
    }
}
