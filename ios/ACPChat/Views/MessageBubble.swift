//
//  MessageBubble.swift
//
//  iMessage-style bubble in our dark design-system palette.
//    - user: right-aligned, DS.primary (indigo-600) fill, white ink
//    - assistant: left-aligned, DS.surface (g800) fill, DS.ink text
//    - system: left-aligned, DS.surfaceAlt fill with subtle yellow stroke
//    - optional screenshot attachment rendered above the text bubble
//    - speaker chip + clock printed below the bubble, not inside
//    - [TURN → ...] footer collapses into a tiny pill under the bubble
//    - tool-call receipt remains collapsible under the whole row
//

import SwiftUI

struct MessageBubble: View {
    let message: StoredMessage
    /// Показывать ли строку времени под bubble'ом. Когда серия сообщений
    /// идёт в одну минуту — ChatView передаёт false для всех кроме
    /// последнего, чтобы не дублировать "HH:MM" под каждым.
    var showsTime: Bool = true

    private let maxWidthFactor: CGFloat = 0.78   // ~78% экрана под bubble
    private let bubbleCorner: CGFloat = 20       // closer to iMessage
    private let attachmentCorner: CGFloat = 18

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 48)
                bubbleColumn
            } else {
                bubbleColumn
                Spacer(minLength: 48)
            }
        }
    }

    private var bubbleColumn: some View {
        // spacing=2 (было 4) — тесней скрепляем header/bubble/footer
        // внутри одного сообщения, чтобы вертикальный воздух тратился
        // только между разными сообщениями.
        VStack(alignment: hAlign, spacing: 2) {
            // Header — mini speaker tag for assistant turns in DG mode.
            if message.role == .assistant, let alias = message.speaker, !alias.isEmpty {
                SpeakerTag(alias: alias)
                    .padding(.horizontal, 2)
            }

            // Optional screenshot (picked via PhotosPicker in the input bar).
            if let data = message.attachmentData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: UIScreen.main.bounds.width * maxWidthFactor)
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: attachmentCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: attachmentCorner, style: .continuous)
                            .stroke(DS.hairlineMid.opacity(0.6), lineWidth: 1)
                    )
            }

            // Text bubble — only render if there's actual text (an image-only
            // message skips the empty bubble).
            let bodyText = stripTurnMarker(message.text)
            if !bodyText.isEmpty || message.isStreaming {
                bubble(for: bodyText)
            }

            // Footer: TURN-маркер (если есть) + время. Время рисуем только
            // на последнем сообщении минутной группы — флаг от ChatView.
            footerLine
        }
        .frame(maxWidth: UIScreen.main.bounds.width * maxWidthFactor,
               alignment: frameAlignment)
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubble(for stripped: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !stripped.isEmpty {
                // Рендерим через ChatMarkdownView: выделяет ``` code
                // fences в монобокс с горизонтальным скроллом + cyan
                // обводкой (для ARM-дизасма от codestral и unidbg-
                // снипов от devstral), inline markdown в прозе.
                ChatMarkdownView(
                    text: stripped,
                    isUser: message.role == .user
                )
            }
            if message.isStreaming {
                streamingRow
            }
            if let json = message.toolCallJSON {
                ToolCallReceipt(json: json)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: bubbleCorner, style: .continuous).fill(bubbleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: bubbleCorner, style: .continuous)
                .stroke(bubbleStroke, lineWidth: bubbleStrokeWidth)
        )
    }

    private var streamingRow: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
                .tint(message.role == .user ? .white.opacity(0.9) : DS.P.s500)
            Text("streaming…")
                .font(DS.tXs)
                .foregroundStyle(message.role == .user
                                 ? Color.white.opacity(0.85)
                                 : DS.inkMuted)
        }
    }

    @ViewBuilder
    private var footerLine: some View {
        // Если ни TURN-маркера, ни разрешения на показ времени — не
        // рисуем пустой HStack (иначе он всё равно забирает ~2pt высоты).
        let marker = turnMarker
        if marker != nil || showsTime {
            HStack(spacing: 6) {
                if let marker {
                    Text(marker)
                        .font(DS.tTagSm)
                        .foregroundStyle(DS.P.s500)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous).fill(DS.P.s500.opacity(0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous).stroke(DS.P.s500.opacity(0.35), lineWidth: 0.5)
                        )
                }
                if showsTime {
                    Text(message.createdAt, style: .time)
                        .font(DS.tXs)
                        .foregroundStyle(DS.inkFaint)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Colors / alignment

    private var hAlign: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleFill: Color {
        switch message.role {
        case .user:      return DS.primary
        case .assistant: return DS.surface
        case .system:    return DS.surfaceAlt
        }
    }

    private var bubbleStroke: Color {
        switch message.role {
        case .user:      return DS.P.p700.opacity(0.6)
        case .assistant: return DS.hairline
        case .system:    return DS.P.yellow.opacity(0.5)
        }
    }

    private var bubbleStrokeWidth: CGFloat {
        message.role == .user ? 0 : 1
    }

    private var textColor: Color {
        switch message.role {
        case .user:      return .white
        case .assistant: return DS.ink
        case .system:    return DS.inkDim
        }
    }

    // MARK: - Turn marker helpers

    private func stripTurnMarker(_ text: String) -> String {
        guard let range = text.range(
            of: #"\[TURN\s*(?:→|->)[^\]]*\]\s*$"#,
            options: .regularExpression
        ) else { return text }
        return String(text[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var turnMarker: String? {
        guard let range = message.text.range(
            of: #"\[TURN\s*(?:→|->)[^\]]*\]"#,
            options: .regularExpression
        ) else { return nil }
        return String(message.text[range])
    }
}

// MARK: - Tool call receipt

struct ToolCallReceipt: View {
    let json: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s2) {
            Button { withAnimation(DS.easeOutFast) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.inkMuted)
                    RChip(text: "TOOL CALL", color: .accent, icon: "wrench.and.screwdriver.fill")
                    if !prettyKind.isEmpty {
                        Text(prettyKind)
                            .font(DS.tCodeXs)
                            .foregroundStyle(DS.inkMuted)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if expanded {
                RCodeBlock(copyable: prettyJSON ?? json) { Text(prettyJSON ?? json) }
            }
        }
    }

    private var prettyKind: String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return "" }
        if let title = obj["title"] as? String { return title }
        if let kind  = obj["kind"]  as? String { return kind }
        return ""
    }

    private var prettyJSON: String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        guard let pretty = try? JSONSerialization.data(
            withJSONObject: obj,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return nil }
        return String(data: pretty, encoding: .utf8)
    }
}
