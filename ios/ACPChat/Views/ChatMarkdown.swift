//
//  ChatMarkdown.swift
//
//  Lightweight chat-bubble markdown renderer. Handles what actually
//  matters for AI replies:
//    - ``` fenced code blocks with optional language tag, horizontal
//      scroll (важно для ARM64-дизасма и длинных unidbg-снипов),
//      copy-to-pasteboard button, cyberpunk cyan outline;
//    - horizontal rules (--- / ***);
//    - inline markdown (bold, italic, `inline code`, links) через
//      AttributedString в прозе между блоками.
//  Full CommonMark не нужен — мы специально рендерим выход агентов,
//  а не произвольный markdown.
//

import SwiftUI

// MARK: - Parser

enum ChatBlock {
    case prose(String)
    case codeFence(lang: String?, body: String)
    case hr
}

enum ChatMarkdown {
    /// Split text into blocks by ``` fences and --- / *** separators.
    /// Preserves original newlines inside code blocks.
    static func parse(_ text: String) -> [ChatBlock] {
        var blocks: [ChatBlock] = []
        var proseLines: [String] = []
        var codeLines: [String] = []
        var codeLang: String? = nil
        var inFence = false

        func flushProse() {
            guard !proseLines.isEmpty else { return }
            let joined = proseLines.joined(separator: "\n")
            proseLines.removeAll()
            let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                blocks.append(.prose(joined))
            }
        }
        func flushCode() {
            let body = codeLines.joined(separator: "\n")
            codeLines.removeAll()
            blocks.append(.codeFence(lang: codeLang, body: body))
            codeLang = nil
        }

        // Use split(separator:omittingEmptySubsequences:) would collapse
        // blanks; we want to keep them. Use components(separatedBy:).
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inFence {
                if trimmed.hasPrefix("```") {
                    flushCode()
                    inFence = false
                } else {
                    codeLines.append(line)
                }
                continue
            }
            // not in fence
            if trimmed.hasPrefix("```") {
                flushProse()
                inFence = true
                let langPart = String(trimmed.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                codeLang = langPart.isEmpty ? nil : langPart
                continue
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushProse()
                blocks.append(.hr)
                continue
            }
            proseLines.append(line)
        }
        // Tail — если стрим оборвался внутри fence, показать как код.
        if inFence {
            flushCode()
        } else {
            flushProse()
        }
        return blocks
    }
}

// MARK: - Rendering

struct ChatMarkdownView: View {
    let text: String
    /// User bubble uses white ink on indigo fill; assistant uses DS.ink.
    let isUser: Bool

    private var blocks: [ChatBlock] { ChatMarkdown.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .prose(let s):
                    proseView(s)
                case .codeFence(let lang, let codeBody):
                    CodeFenceBlock(lang: lang, code: codeBody, userTint: isUser)
                case .hr:
                    Rectangle()
                        .fill(isUser ? Color.white.opacity(0.25) : DS.hairline)
                        .frame(height: 1)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func proseView(_ s: String) -> some View {
        let ink: Color = isUser ? .white : DS.ink
        Group {
            if let attr = try? AttributedString(
                markdown: s,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            ) {
                Text(attr)
            } else {
                Text(s)
            }
        }
        .font(DS.tLead)
        .foregroundStyle(ink)
        .textSelection(.enabled)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Code fence block

/// Dedicated view for ``` fenced code: dark background, monospace,
/// horizontal scroll for long lines, language tag + copy button.
struct CodeFenceBlock: View {
    let lang: String?
    /// Named `code` not `body` to avoid colliding with `View.body`.
    let code: String
    /// When bubble is the user's (indigo), we slightly brighten border.
    var userTint: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // Body: horizontal scroll, monospace, preserve whitespace.
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(DS.tCodeSm)
                    .foregroundStyle(Color(hex: 0xE5E7EB))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DS.P.g900)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    DS.P.s500.opacity(userTint ? 0.35 : 0.22),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let lang, !lang.isEmpty {
                Text(lang.lowercased())
                    .font(DS.tCodeXs)
                    .foregroundStyle(DS.P.s500)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DS.P.s500.opacity(0.12)))
                    .overlay(Capsule().stroke(DS.P.s500.opacity(0.40), lineWidth: 0.5))
            } else {
                Text("code")
                    .font(DS.tCodeXs)
                    .foregroundStyle(Color(hex: 0x9CA3AF))
            }
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = code
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x9CA3AF))
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.black.opacity(0.35))
    }
}
