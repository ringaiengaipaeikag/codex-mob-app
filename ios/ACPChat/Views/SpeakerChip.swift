//
//  SpeakerChip.swift
//
//  Speaker identifier rendered as a REGHelp pill chip (indigo / cyan /
//  pink / gray family). Tint is mapped from the speaker alias.
//

import SwiftUI

struct SpeakerChip: View {
    let alias: String?
    var body: some View {
        let speaker = SpeakerRegistry.lookup(alias)
        HStack(spacing: DS.s2) {
            RChip(text: speaker.id.uppercased(), color: chipColor(for: speaker.id))
            Text(speaker.displayName)
                .font(DS.tXs)
                .foregroundStyle(DS.inkMuted)
        }
    }
}

struct SpeakerTag: View {
    let alias: String?
    var body: some View {
        let speaker = SpeakerRegistry.lookup(alias)
        RChip(text: speaker.id.uppercased(), color: chipColor(for: speaker.id))
    }
}

/// Map agent alias → REGHelp chip color.
/// - opus / sonnet → indigo (primary family)
/// - codestral / devstral → cyan (secondary)
/// - magistral → orange (warm)
/// - mistral → yellow
/// - scout → green
/// - local/unknown → gray
func chipColor(for alias: String) -> ChipColor {
    switch alias.lowercased() {
    case "opus", "sonnet":        return .indigo
    case "codestral", "devstral": return .cyan
    case "magistral":             return .orange
    case "mistral":               return .yellow
    case "scout":                 return .green
    case "groqwen", "gptoss", "llama70":
                                  return .gray
    default:                      return .gray
    }
}

// Legacy for MessageBubble / older call-sites
func badgeColor(for alias: String) -> ChipColor { chipColor(for: alias) }
