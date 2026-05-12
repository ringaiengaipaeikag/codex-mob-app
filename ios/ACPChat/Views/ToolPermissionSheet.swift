//
//  ToolPermissionSheet.swift
//
//  Flowbite modal pattern for permission request. Uses:
//    - FBAlert (warning) for the explanation
//    - FBCodeBlock (with copy) for the payload
//    - FBButton primary / alternative / danger row
//

import SwiftUI

struct ToolPermissionSheet: View {
    let request: PermissionRequest
    let onDecision: (PermissionOutcome) -> Void

    @State private var rejectReason: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s5) {
                    header
                    FBAlert(
                        kind: .warning,
                        title: "Review before approving",
                        text: "The agent wants to run a tool. Check the payload — especially paths, commands, and any write targets."
                    )
                    summaryCard
                    if let payload = prettyPayload {
                        payloadCard(payload)
                    }
                    decisionCard
                }
                .padding(DS.s4)
            }
            .background(DS.surfaceAlt)
            .navigationTitle("Tool permission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDecision(.reject(reason: "dismissed"))
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.inkDim)
                    }
                }
            }
        }
    }

    // MARK: - Cards

    private var header: some View {
        HStack(spacing: DS.s2) {
            FBBadge(text: kindText, color: kindBadge, uppercase: true,
                    icon: "wrench.and.screwdriver.fill")
            Spacer()
            Text(request.toolCallSummary)
                .font(DS.tH4)
                .foregroundStyle(DS.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionLabel("Summary")
                if let title = request.raw["toolCall", "title"]?.stringValue {
                    row("title", title)
                }
                if let kind = request.raw["toolCall", "kind"]?.stringValue {
                    row("kind", kind)
                }
                if let id = request.raw["toolCall", "toolCallId"]?.stringValue {
                    row("toolCallId", id)
                }
            }
        }
    }

    private func payloadCard(_ json: String) -> some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionLabel("Payload")
                FBCodeBlock(copyable: json) { Text(json) }
            }
        }
    }

    private var decisionCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionLabel("Decision")

                HStack(spacing: DS.s2) {
                    FBButton(
                        title: "Allow once",
                        icon: "checkmark",
                        variant: .primary,
                        size: .md,
                        fullWidth: true
                    ) {
                        onDecision(.allow); dismiss()
                    }
                    FBButton(
                        title: "Allow always",
                        icon: "infinity",
                        variant: .outlinePrimary,
                        size: .md,
                        fullWidth: true
                    ) {
                        onDecision(.allowAlways); dismiss()
                    }
                }

                FBTextField(
                    label: "Reject reason (optional)",
                    placeholder: "e.g. unsafe path",
                    text: $rejectReason,
                    mono: true
                )

                FBButton(
                    title: "Reject",
                    icon: "xmark.octagon.fill",
                    variant: .danger,
                    size: .md,
                    fullWidth: true
                ) {
                    let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
                    onDecision(.reject(reason: reason.isEmpty ? "user rejected" : reason))
                    dismiss()
                }
            }
        }
    }

    // MARK: - Small pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(DS.tKicker)
            .tracking(0.6)
            .foregroundStyle(DS.inkMuted)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s3) {
            Text(label)
                .font(DS.tCodeSm)
                .foregroundStyle(DS.inkMuted)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(DS.tCode)
                .foregroundStyle(DS.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var kindText: String {
        request.raw["toolCall", "kind"]?.stringValue?.uppercased() ?? "TOOL"
    }

    private var kindBadge: BadgeColor {
        switch request.raw["toolCall", "kind"]?.stringValue {
        case "execute": return .orange
        case "read":    return .indigo
        case "edit":    return .purple
        case "delete":  return .red
        case "fetch":   return .cyan
        default:        return .gray
        }
    }

    private var prettyPayload: String? {
        guard let raw = request.raw["toolCall"] else { return nil }
        guard let data = try? JSONEncoder().encode(raw) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let pretty = try? JSONSerialization.data(
            withJSONObject: obj,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return nil }
        return String(data: pretty, encoding: .utf8)
    }
}
