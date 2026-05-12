//
//  CommandMenu.swift
//
//  Input-bar "+" menu. Single access point to every chat-command the
//  router (`src/cli/chat.ts`) accepts. Sections (always visible):
//
//    • Attachments   → Attach photo, Attach / Hide project files
//    • Model         → /opus /sonnet /haiku /qwen /groq /cerebras /free /auto
//    • Ask agent     → chat ask @<alias> — one submenu per live speaker
//                      (codestral, devstral, magistral, mistral, scout,
//                       opus, sonnet, qwen, cerebras, gptoss, groqwen)
//    • Chat          → say, paste, ensemble, round, auto, turn, watch,
//                      debate, pitfall, trick, ls, models, log, reset, new
//    • Poll          → chat poll <tag>, close:<tag>, confirm:<tag>
//    • Context       → chat ctx +manual|skill|pitfall|trick|role,
//                      clear, mode lean|full
//    • Mode          → chat mode dg|default
//
//  The menu just signals intent — host `ChatView` owns the TextField
//  binding, PhotosPicker, FileDrawer and the send/context plumbing.
//  Templates that need user edits carry `<placeholder>`-style slots.
//
//  NB: DG orchestrator is a runtime mode (`chat mode dg`), not a compile
//  flag — so this menu no longer hides commands behind `isDGMode`. A
//  user in "default" mode can still inspect the full command surface.
//

import SwiftUI
import PhotosUI

struct CommandMenu: View {
    /// Retained for API compatibility — currently unused (previously
    /// gated the Chat/* section). Kept so call-sites don't churn.
    let isDGMode: Bool

    /// Whether the FileDrawer is currently open — controls the label
    /// ("Attach files" vs. "Hide files") + the icon.
    let fileDrawerOpen: Bool

    /// Parent-owned PhotosPicker binding.
    @Binding var photoPickerPresented: Bool

    /// Toggle the file drawer panel visibility.
    let onToggleFileDrawer: () -> Void

    /// Replace input text with the given template (placeholders stay
    /// as `<…>` so the user can tab through them).
    let onInsertTemplate: (String) -> Void

    /// Commit a model slash-command as a single token.
    let onModelCommand: (String) -> Void

    /// Whether any send is currently in flight — disables the menu.
    let isBusy: Bool

    var body: some View {
        // iOS SwiftUI Menu на iPhone ограничивает top-level items (≈12),
        // остальное обрезается без предупреждения. Поэтому верхний
        // уровень — компактный: 2 attach-кнопки, секция Model и 5
        // категорий как вложенные submenu. Все команды роутера доступны,
        // но ничего не обрезается.
        Menu {
            attachmentsSection
            modelSection
            askAgentMenu
            chatCommandsMenu
            pollMenu
            contextMenu
            modeMenu
        } label: {
            plusButtonLabel
        }
        .disabled(isBusy)
    }

    // MARK: - Attachments

    @ViewBuilder
    private var attachmentsSection: some View {
        Section {
            Button {
                photoPickerPresented = true
            } label: {
                Label("Attach photo", systemImage: "photo.on.rectangle")
            }

            Button {
                onToggleFileDrawer()
            } label: {
                Label(
                    fileDrawerOpen ? "Hide project files" : "Attach project files",
                    systemImage: fileDrawerOpen ? "folder.fill.badge.minus" : "folder.badge.plus"
                )
            }
        }
    }

    // MARK: - Model

    @ViewBuilder
    private var modelSection: some View {
        Section("Model") {
            ForEach(ModelPreset.all) { preset in
                Button {
                    onModelCommand(preset.slash)
                } label: {
                    Label(preset.title, systemImage: preset.icon)
                }
            }
        }
    }

    // MARK: - Ask agent

    /// Per-alias submenu — pre-fills `chat ask <alias> "<prompt>"` so the
    /// user lands at the prompt slot. Icons lifted from each agent's role
    /// (ARM disasm → chevron, VM hypothesis → brain, etc.).
    @ViewBuilder
    private var askAgentMenu: some View {
        Menu {
            ForEach(AgentAlias.all) { agent in
                Button {
                    onInsertTemplate("chat ask \(agent.alias) \"<prompt>\"")
                } label: {
                    Label(agent.displayTitle, systemImage: agent.icon)
                }
            }
        } label: {
            Label("Ask agent…", systemImage: "person.crop.circle.badge.questionmark")
        }
    }

    // MARK: - Chat/* commands

    /// Submenu — 17 верхнеуровневых `chat <verb>` команд из
    /// `src/cli/chat.ts`. Разбиты на секции: session-control, composing,
    /// orchestration, dg-context. Список плоский по умолчанию, но iOS
    /// показывает секции с заголовками.
    @ViewBuilder
    private var chatCommandsMenu: some View {
        Menu {
            Section("Session") {
                ForEach(ChatCommandPreset.sessionGroup) { cmd in
                    Button { onInsertTemplate(cmd.template) }
                    label: { Label(cmd.title, systemImage: cmd.icon) }
                }
            }
            Section("Composing") {
                ForEach(ChatCommandPreset.composingGroup) { cmd in
                    Button { onInsertTemplate(cmd.template) }
                    label: { Label(cmd.title, systemImage: cmd.icon) }
                }
            }
            Section("Orchestration") {
                ForEach(ChatCommandPreset.orchestrationGroup) { cmd in
                    Button { onInsertTemplate(cmd.template) }
                    label: { Label(cmd.title, systemImage: cmd.icon) }
                }
            }
            Section("DG context") {
                ForEach(ChatCommandPreset.dgGroup) { cmd in
                    Button { onInsertTemplate(cmd.template) }
                    label: { Label(cmd.title, systemImage: cmd.icon) }
                }
            }
        } label: {
            Label("Chat commands…", systemImage: "terminal")
        }
    }

    // MARK: - Poll

    @ViewBuilder
    private var pollMenu: some View {
        Menu {
            Button {
                onInsertTemplate("chat poll <tag> <voters> \"<question>\"")
            } label: {
                Label("poll <tag>", systemImage: "checklist")
            }
            Button {
                onInsertTemplate("chat poll close:<tag> <voters> \"<question>\"")
            } label: {
                Label("poll close:<tag>", systemImage: "flag.checkered")
            }
            Button {
                onInsertTemplate("chat poll confirm:<tag> <voters> \"<question>\"")
            } label: {
                Label("poll confirm:<tag>", systemImage: "checkmark.seal")
            }
        } label: {
            Label("Poll…", systemImage: "checklist")
        }
    }

    // MARK: - Context (`chat ctx …`)

    @ViewBuilder
    private var contextMenu: some View {
        Menu {
            Button {
                onInsertTemplate("chat ctx +manual <N>")
            } label: { Label("+ manual <N>", systemImage: "book.pages") }

            Button {
                onInsertTemplate("chat ctx +skill <name>")
            } label: { Label("+ skill <name>", systemImage: "hammer") }

            Button {
                onInsertTemplate("chat ctx +pitfall <N>")
            } label: { Label("+ pitfall <N>", systemImage: "exclamationmark.triangle") }

            Button {
                onInsertTemplate("chat ctx +trick <N>")
            } label: { Label("+ trick <N>", systemImage: "shield.lefthalf.filled") }

            Button {
                onInsertTemplate("chat ctx +role <alias>")
            } label: { Label("+ role <alias>", systemImage: "person.text.rectangle") }

            Section {
                Button {
                    onInsertTemplate("chat ctx clear")
                } label: { Label("clear", systemImage: "trash") }

                Button {
                    onInsertTemplate("chat ctx mode lean")
                } label: { Label("mode lean", systemImage: "leaf") }

                Button {
                    onInsertTemplate("chat ctx mode full")
                } label: { Label("mode full", systemImage: "text.justify") }
            }
        } label: {
            Label("Context…", systemImage: "doc.badge.plus")
        }
    }

    // MARK: - Mode

    @ViewBuilder
    private var modeMenu: some View {
        Menu {
            Button {
                onInsertTemplate("chat mode dg")
            } label: { Label("mode dg", systemImage: "cpu") }

            Button {
                onInsertTemplate("chat mode default")
            } label: { Label("mode default", systemImage: "arrow.uturn.backward") }
        } label: {
            Label("Mode…", systemImage: "slider.horizontal.3")
        }
    }

    // MARK: - Plus button label (unchanged)

    private var plusButtonLabel: some View {
        Image(systemName: "plus")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DS.ink)
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(DS.surface.opacity(0.55))
                }
            )
            .overlay(
                Circle().stroke(
                    LinearGradient(
                        colors: [DS.P.s500.opacity(0.8), DS.P.p500.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: DS.P.s500.opacity(0.35), radius: 6, x: 0, y: 0)
    }
}

// MARK: - Presets

/// Slash-command presets for model override. Mirrors the router alias
/// map — must stay in sync with `src/router.ts` + `src/cli/chat.ts`
/// `SPEAKERS` registry.
struct ModelPreset: Identifiable {
    let id = UUID()
    let title: String
    let slash: String
    let icon: String

    static let all: [ModelPreset] = [
        .init(title: "Opus 4.7",         slash: "/opus",     icon: "cpu"),
        .init(title: "Sonnet 4.6",       slash: "/sonnet",   icon: "waveform"),
        .init(title: "Haiku 4.5",        slash: "/haiku",    icon: "leaf"),
        .init(title: "Qwen 3 Coder",     slash: "/qwen",     icon: "chevron.left.forwardslash.chevron.right"),
        .init(title: "Groq (free)",      slash: "/groq",     icon: "bolt"),
        .init(title: "Cerebras (free)",  slash: "/cerebras", icon: "brain"),
        .init(title: "Free tier (auto)", slash: "/free",     icon: "gift"),
        .init(title: "Router auto",      slash: "/auto",     icon: "wand.and.stars"),
    ]
}

/// Every `chat <cmd>` verb that the router CLI parses. Templates land
/// in the TextField with `<placeholder>` slots; the user edits and sends.
/// See `src/cli/chat.ts` — this list mirrors the top-level `if (cmd === "…")`
/// branches, minus `ask` / `poll` / `ctx` / `mode` (those have their own
/// richer submenus elsewhere in the menu).
struct ChatCommandPreset: Identifiable {
    let id = UUID()
    let title: String
    let template: String
    let icon: String

    // Session-control ─── transcript lifecycle / inspection.
    static let sessionGroup: [ChatCommandPreset] = [
        .init(title: "new (reset transcript)",
              template: "chat new",
              icon: "sparkles"),
        .init(title: "use <log>",
              template: "chat use <logfile>",
              icon: "folder.badge.gearshape"),
        .init(title: "ls (sessions)",
              template: "chat ls",
              icon: "list.bullet.rectangle"),
        .init(title: "log (print transcript)",
              template: "chat log",
              icon: "doc.text"),
        .init(title: "reset (wipe transcript)",
              template: "chat reset",
              icon: "arrow.counterclockwise"),
        .init(title: "models (list aliases)",
              template: "chat models",
              icon: "list.star"),
    ]

    // Composing ─── human / named-alias message injection.
    static let composingGroup: [ChatCommandPreset] = [
        .init(title: "say",
              template: "chat say \"<text>\"",
              icon: "text.bubble"),
        .init(title: "paste",
              template: "chat paste",
              icon: "doc.on.clipboard"),
        .init(title: "as <alias>",
              template: "chat as <alias> \"<text>\"",
              icon: "person.crop.square.filled.and.at.rectangle"),
    ]

    // Orchestration ─── multi-agent rounds, autopilot, debates.
    static let orchestrationGroup: [ChatCommandPreset] = [
        .init(title: "ensemble",
              template: "chat ensemble \"<prompt>\"",
              icon: "person.3.sequence"),
        .init(title: "round",
              template: "chat round \"<prompt>\"",
              icon: "arrow.triangle.2.circlepath"),
        .init(title: "auto",
              template: "chat auto \"<prompt>\" --max-hops 5",
              icon: "arrow.triangle.turn.up.right.diamond"),
        .init(title: "turn",
              template: "chat turn",
              icon: "arrow.forward.circle"),
        .init(title: "watch",
              template: "chat watch --max-hops 10",
              icon: "eye"),
        .init(title: "debate",
              template: "chat debate \"<prompt>\" --rounds 2 --members @a,@b,@c",
              icon: "person.2.wave.2"),
    ]

    // DG context ─── pitfall / trick context injection (dg mode only).
    static let dgGroup: [ChatCommandPreset] = [
        .init(title: "pitfall <N>",
              template: "chat pitfall <N> @<alias> \"<prompt>\"",
              icon: "exclamationmark.triangle"),
        .init(title: "trick <N>",
              template: "chat trick <N> @<alias> \"<prompt>\"",
              icon: "shield.lefthalf.filled"),
    ]

    /// Flat list for any legacy call-site that still uses `.all`.
    static let all: [ChatCommandPreset] =
        sessionGroup + composingGroup + orchestrationGroup + dgGroup
}

/// Every agent alias the router knows about (`SPEAKERS` registry in
/// `src/cli/chat.ts`). Used to build the `chat ask @<alias>` submenu
/// so the user doesn't have to memorise aliases. Icons try to match
/// the role: ARM disasm → forwardslash-chevron, VM semantics → brain,
/// trace parsing → waveform, etc. Keep this list in sync with
/// `SPEAKERS` — adding a role here is free, adding a role there needs
/// a provider wiring.
struct AgentAlias: Identifiable {
    let id = UUID()
    let alias: String
    let display: String
    let role: String
    let icon: String

    var displayTitle: String { "\(alias) · \(role)" }

    static let all: [AgentAlias] = [
        .init(alias: "codestral",
              display: "Codestral",
              role: "Static Analysis",
              icon: "chevron.left.forwardslash.chevron.right"),
        .init(alias: "devstral",
              display: "Devstral",
              role: "Impl / harness",
              icon: "hammer"),
        .init(alias: "magistral",
              display: "Magistral",
              role: "VM hypothesis",
              icon: "brain"),
        .init(alias: "mistral",
              display: "Mistral",
              role: "Sanity-check",
              icon: "checkmark.seal"),
        .init(alias: "scout",
              display: "Scout",
              role: "Dump / trace parsing",
              icon: "waveform.path"),
        .init(alias: "opus",
              display: "Opus 4.7",
              role: "Senior Reasoner",
              icon: "cpu"),
        .init(alias: "sonnet",
              display: "Sonnet 4.6",
              role: "Peer Reasoner",
              icon: "waveform"),
        .init(alias: "qwen",
              display: "Qwen 3 Coder",
              role: "Code gen (Cerebras)",
              icon: "chevron.left.slash.chevron.right"),
        .init(alias: "cerebras",
              display: "Cerebras",
              role: "Speed tier",
              icon: "bolt.heart"),
        .init(alias: "groqwen",
              display: "GroqWen",
              role: "Free alt-angle",
              icon: "bolt.badge.automatic"),
        .init(alias: "gptoss",
              display: "GPT-OSS",
              role: "Free alt-angle",
              icon: "gift"),
    ]
}
