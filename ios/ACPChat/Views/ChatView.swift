//
//  ChatView.swift
//
//  iMessage-feel transcript over a cyberpunk wallpaper.
//    - bg: CyberpunkBackground (grid + scanlines + radial glow)
//    - transcript: MessageBubble, right-aligned user / left assistant
//    - input bar: attach (+ PhotosPicker) · TextField · round send (arrow.up)
//    - streaming stops cleanly on view disappear (draft semantics)
//    - local push notifications fire when a streaming reply finishes while
//      the app is backgrounded (no APNs needed, Personal Team friendly)
//    - permission sheet mapped to client.onRequestPermission
//

import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications

struct ChatView: View {
    @Bindable var session: StoredSession
    @Environment(ACPClient.self) private var client
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var input: String = ""
    @State private var sending: Bool = false
    @State private var resumeAttempted = false
    @State private var pendingPermission: PermissionRequest?
    @State private var permissionContinuation: CheckedContinuation<PermissionOutcome, Never>?

    // Photo attachment staging (before send).
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var photoPickerPresented: Bool = false

    // Project-file attachment drawer.
    @State private var fileDrawer = FileDrawerModel()
    @State private var fileDrawerOpen: Bool = false

    // Track the currently-streaming assistant message id. Used so
    // `onDisappear` can mark it as finished (drop the spinner / timer).
    @State private var streamingMessageId: UUID?

    var messages: [StoredMessage] {
        session.messages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            attachmentPreview
            FileDrawer(model: fileDrawer, isOpen: $fileDrawerOpen)
            Divider().background(DS.hairline.opacity(0.4))
            inputBar
        }
        .background(CyberpunkBackground().ignoresSafeArea())
        .photosPicker(
            isPresented: $photoPickerPresented,
            selection: $pickedItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .navigationTitle(session.tag)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await resumeSessionIfNeeded() }
        .onAppear {
            wirePermissionHandler()
            requestNotificationPermissionIfNeeded()
        }
        .onDisappear { freezeStreamingAsDraft() }
        .onChange(of: pickedItem) { _, newItem in
            Task { await loadPickedImage(from: newItem) }
        }
        .sheet(item: $pendingPermission) { req in
            ToolPermissionSheet(
                request: req,
                onDecision: { outcome in
                    permissionContinuation?.resume(returning: outcome)
                    permissionContinuation = nil
                    pendingPermission = nil
                }
            )
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // spacing=2 (было 10) + vertical padding s2 (было s4) — на
                // iPhone это даёт максимальную полезную площадь. Плюс
                // showsTime в MessageBubble: время показываем только
                // когда пауза в диалоге ≥60с или это последнее
                // сообщение. Соседние bubble'ы одной минуты идут
                // вплотную, как в iMessage.
                LazyVStack(spacing: 2) {
                    let msgs = messages
                    ForEach(Array(msgs.enumerated()), id: \.element.id) { idx, msg in
                        MessageBubble(
                            message: msg,
                            showsTime: shouldShowTime(for: idx, in: msgs)
                        )
                        .id(msg.id)
                    }
                    if msgs.isEmpty { emptyState }
                }
                .padding(.horizontal, DS.s3)
                .padding(.vertical, DS.s2)
            }
            .onChange(of: messages.last?.text) { _, _ in
                if let id = messages.last?.id {
                    withAnimation(DS.easeOutFast) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// Показываем время под сообщением ТОЛЬКО если:
    ///   - это последнее в ленте, ИЛИ
    ///   - разница с следующим ≥ 60 секунд (пауза в диалоге).
    /// Соседние сообщения разных ролей в ту же минуту — время не дублируем,
    /// экономим ~20pt вертикали на каждое такое сообщение.
    private func shouldShowTime(for idx: Int, in list: [StoredMessage]) -> Bool {
        guard idx < list.count else { return true }
        let cur = list[idx]
        let next = idx + 1 < list.count ? list[idx + 1] : nil
        guard let next else { return true }
        let dt = next.createdAt.timeIntervalSince(cur.createdAt)
        return dt >= 60
    }

    private var emptyState: some View {
        VStack(spacing: DS.s3) {
            Image(systemName: "waveform.path.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DS.P.s500.opacity(0.8))
            Text("Session ready")
                .font(DS.tH4)
                .foregroundStyle(DS.ink)
            Text("Отправьте первый prompt чтобы запустить агента.")
                .font(DS.tSm)
                .foregroundStyle(DS.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.s10)
    }

    // MARK: - Attachment preview (above input bar)

    @ViewBuilder
    private var attachmentPreview: some View {
        if let data = pickedImageData, let ui = UIImage(data: data) {
            HStack(spacing: 10) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.P.s500.opacity(0.5), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screenshot attached")
                        .font(DS.body(13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("\(Int((Double(data.count) / 1024).rounded())) KB")
                        .font(DS.tXs)
                        .foregroundStyle(DS.inkMuted)
                }
                Spacer()
                Button {
                    pickedItem = nil
                    pickedImageData = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(DS.inkMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.s4)
            .padding(.vertical, DS.s2)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(Color.black.opacity(0.40))
                }
            )
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // (+) attach / commands menu — photos, file drawer, models,
            // chat/* commands (DG orchestrator only).
            CommandMenu(
                isDGMode: session.mode == "dg",
                fileDrawerOpen: fileDrawerOpen,
                photoPickerPresented: $photoPickerPresented,
                onToggleFileDrawer: {
                    withAnimation(.easeOut(duration: 0.18)) {
                        fileDrawerOpen.toggle()
                    }
                },
                onInsertTemplate: { template in
                    let sep = input.isEmpty ? "" : (input.hasSuffix("\n") ? "" : "\n")
                    input += "\(sep)\(template)"
                },
                onModelCommand: { slash in
                    // Model presets take a single slash-token; place at
                    // the start of the current input so the router reads
                    // it before the prompt body.
                    input = "\(slash) \(input)"
                },
                isBusy: sending
            )

            // Message field — HUD-glass: ultraThinMaterial + тёмная
            // заливка поверх + cyan/magenta неоновая обводка. iOS 26
            // Liquid Glass halo при этом ложится внутрь stroke'а и
            // читается как часть стиля.
            TextField("Message", text: $input, axis: .vertical)
                .font(DS.tBody)
                .foregroundStyle(DS.ink)
                .tint(DS.P.s500)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DS.P.s500.opacity(0.55),
                                    DS.P.a500.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: DS.P.s500.opacity(0.20), radius: 6, x: 0, y: 0)
                .disabled(sending || client.status != .connected)

            // Send — iMessage-style: small round button, icon-only.
            if sending {
                Button { Task { await client.cancel(sessionId: session.id) } } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(DS.P.red))
                }
                .buttonStyle(.plain)
            } else {
                Button { Task { await send() } } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(sendActive ? DS.primary : DS.inkFaint))
                }
                .buttonStyle(.plain)
                .disabled(!sendActive)
            }
        }
        .padding(.horizontal, DS.s3)
        .padding(.vertical, DS.s2)
        .background(Color.black.opacity(0.35))
    }

    private var sendActive: Bool {
        let hasText = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttach = pickedImageData != nil
        return (hasText || hasAttach) && client.status == .connected
    }

    // MARK: - Actions

    private func resumeSessionIfNeeded() async {
        guard !resumeAttempted else { return }
        resumeAttempted = true
        do {
            try await client.loadSession(routerSessionId: session.id, cwd: "/path/to/project")
        } catch {
            print("loadSession soft-fail: \(error)")
        }
    }

    private func loadPickedImage(from item: PhotosPickerItem?) async {
        guard let item else { pickedImageData = nil; return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // Normalise through UIImage to strip orientation + recompress
                // if needed (keeps SwiftData blob compact).
                if let ui = UIImage(data: data),
                   let jpeg = ui.jpegData(compressionQuality: 0.85) {
                    pickedImageData = jpeg
                } else {
                    pickedImageData = data
                }
            }
        } catch {
            print("picker load failed: \(error)")
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let attach = pickedImageData
        let hasFiles = !fileDrawer.selected.isEmpty
        guard !text.isEmpty || attach != nil || hasFiles else { return }
        input = ""
        sending = true
        defer { sending = false }

        // ── Router-CLI-команды ────────────────────────────────────────
        // Если ввод начинается с `chat …` — это не prompt для агента,
        // а команда к chat.ts orchestrator'у (ask / round / ensemble /
        // poll / auto / debate / ctx / …). Раньше они просто улетали в
        // session/prompt как текст, и удалённый агент их игнорировал.
        // Теперь идут через chat/exec: bridge спаунит `node chat.js …`,
        // stdout кладётся в assistant-bubble. Вложения для chat-команд
        // не имеют смысла — сохраняем их в user-сообщении, но не
        // передаём в argv.
        if let argv = parseChatCommand(from: text) {
            await runChatCommand(
                argv: argv,
                rawText: text,
                attach: attach,
                hasFiles: hasFiles
            )
            return
        }

        // Stored-message text is what the user typed — attached files get
        // appended to the *outgoing* prompt only, not to the transcript
        // bubble (the transcript shows a compact "N files attached" hint).
        let fileHint = hasFiles
            ? "\n\n📎 \(fileDrawer.selected.count) project file(s) attached"
            : ""
        let userMsg = StoredMessage(
            role: .user,
            text: text + fileHint,
            attachmentData: attach,
            session: session
        )
        modelContext.insert(userMsg)
        session.updatedAt = Date()
        try? modelContext.save()

        // Clear staging right after capture so the user can start typing next.
        pickedItem = nil
        pickedImageData = nil

        let assistantMsg = StoredMessage(
            role: .assistant, speaker: nil, text: "", isStreaming: true, session: session
        )
        modelContext.insert(assistantMsg)
        streamingMessageId = assistantMsg.id
        try? modelContext.save()

        // Build the final outgoing prompt: text + fenced-code dump of
        // every file the user selected (read through the bridge fs/read
        // allowlist, not local iOS paths).
        var promptText = text
        if hasFiles {
            let block = await fileDrawer.buildContextBlock(using: client)
            if !block.isEmpty {
                promptText = promptText.isEmpty ? block : promptText + "\n" + block
            }
        }
        // Keep selection for next round unless the drawer is currently
        // open — an open drawer signals the user is actively managing
        // files and probably wants a fresh slate after send.
        if fileDrawerOpen { fileDrawer.clear() }

        do {
            let stream = try await client.prompt(sessionId: session.id, text: promptText)
            for await event in stream {
                handle(event: event, target: assistantMsg)
            }
            assistantMsg.isStreaming = false
            session.updatedAt = Date()
            try? modelContext.save()
            streamingMessageId = nil

            // Push local notification if user is not in the app right now.
            if scenePhase != .active {
                let preview = assistantMsg.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                postLocalNotification(
                    title: session.tag,
                    body: String(preview.prefix(160))
                )
            }
        } catch {
            assistantMsg.text += "\n\n⚠ error: \(error.localizedDescription)"
            assistantMsg.isStreaming = false
            streamingMessageId = nil
            try? modelContext.save()
        }
    }

    // MARK: - Router CLI (chat/exec) branch

    /// Если `text` начинается с `chat ` — парсит его в argv по shell-правилам
    /// (пробел разделяет, `"…"` / `'…'` группируют, `\` эскейпит). Возвращает
    /// argv БЕЗ ведущего `chat`. Если первое слово не `chat` — nil.
    private func parseChatCommand(from text: String) -> [String]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Минимум: "chat <verb>". Сам по себе `chat` без аргументов отдадим
        // агенту — пусть Claude объяснит, что такое chat, это валидный prompt.
        guard trimmed.hasPrefix("chat ") else { return nil }
        let rest = String(trimmed.dropFirst(5)) // убираем "chat "
        let tokens = shellTokenize(rest)
        guard !tokens.isEmpty else { return nil }
        return tokens
    }

    /// POSIX-ish токенайзер: пробел — разделитель, двойные/одинарные кавычки
    /// группируют, backslash эскейпит следующий символ (в т.ч. кавычку).
    /// Не обрабатывает env-expansion, pipe'ов, redirections — оно нам и не
    /// нужно, bridge всё равно валидирует argv[0] против белого списка.
    private func shellTokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var cur = ""
        var quote: Character? = nil
        var escape = false
        for ch in s {
            if escape {
                cur.append(ch)
                escape = false
                continue
            }
            if ch == "\\" {
                escape = true
                continue
            }
            if let q = quote {
                if ch == q { quote = nil } else { cur.append(ch) }
                continue
            }
            if ch == "\"" || ch == "'" {
                quote = ch
                continue
            }
            if ch.isWhitespace {
                if !cur.isEmpty { tokens.append(cur); cur = "" }
                continue
            }
            cur.append(ch)
        }
        if !cur.isEmpty { tokens.append(cur) }
        return tokens
    }

    /// Отправляет chat-команду через bridge chat/exec. Кладёт пользователю
    /// исходный текст как обычно, а stdout/stderr экзекутора — в assistant.
    private func runChatCommand(
        argv: [String],
        rawText: String,
        attach: Data?,
        hasFiles: Bool
    ) async {
        // User bubble (ровно как ввели). Attach сохраняем — это же история.
        let fileHint = hasFiles
            ? "\n\n📎 \(fileDrawer.selected.count) file(s) ignored (chat/exec)"
            : ""
        let userMsg = StoredMessage(
            role: .user,
            text: rawText + fileHint,
            attachmentData: attach,
            session: session
        )
        modelContext.insert(userMsg)
        session.updatedAt = Date()
        try? modelContext.save()

        pickedItem = nil
        pickedImageData = nil
        // Chat-команда живёт вне файлового контекста, так что очистим
        // выбранные файлы независимо от состояния drawer'а — иначе при
        // следующем обычном promt'е пользователь будет удивлён, что
        // таскается старый context block.
        fileDrawer.clear()

        // Обозначим спикера — alias, к кому реально ушла команда, полезно
        // визуально отличать `ask codestral` от `ask magistral` и т.п.
        let speakerLabel: String? = {
            if argv.first == "ask", argv.count >= 2 { return argv[1] }
            if argv.first == "as", argv.count >= 2 { return argv[1] }
            return argv.first
        }()
        let assistantMsg = StoredMessage(
            role: .assistant,
            speaker: speakerLabel,
            text: "",
            isStreaming: true,
            session: session
        )
        modelContext.insert(assistantMsg)
        streamingMessageId = assistantMsg.id
        try? modelContext.save()

        do {
            let result = try await client.chatExec(argv: argv, stdin: nil)
            assistantMsg.text = result.displayText
            assistantMsg.isStreaming = false
            session.updatedAt = Date()
            try? modelContext.save()
            streamingMessageId = nil

            if scenePhase != .active {
                let preview = result.displayText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                postLocalNotification(
                    title: "chat \(argv.joined(separator: " "))",
                    body: String(preview.prefix(160))
                )
            }
        } catch {
            assistantMsg.text = "⚠ chat/exec: \(error.localizedDescription)"
            assistantMsg.isStreaming = false
            streamingMessageId = nil
            try? modelContext.save()
        }
    }

    private func handle(event: SessionEvent, target: StoredMessage) {
        switch event {
        case .textDelta(let s):
            target.text += s
        case .thinkingDelta:
            break
        case .toolCall(let raw), .toolCallUpdate(let raw):
            if target.toolCallJSON == nil,
               let data = try? JSONEncoder().encode(raw),
               let str = String(data: data, encoding: .utf8) {
                target.toolCallJSON = str
            }
        case .plan, .raw:
            break
        case .error(let m):
            target.text += "\n\n⚠ \(m)"
        }
    }

    private func wirePermissionHandler() {
        client.onRequestPermission = { req in
            await withCheckedContinuation { cont in
                permissionContinuation = cont
                pendingPermission = req
            }
        }
    }

    /// User left the chat while streaming is active. We do NOT cancel the
    /// remote prompt (it may still be valuable — the agent will keep
    /// writing into the StoredMessage). But the spinner / «streaming…»
    /// label should freeze so the UI looks like a draft. The caller's
    /// for-await loop still runs in the background task on ACPClient.
    private func freezeStreamingAsDraft() {
        let active = messages.filter { $0.isStreaming }
        guard !active.isEmpty else { return }
        for m in active {
            m.isStreaming = false
        }
        try? modelContext.save()
        streamingMessageId = nil
    }

    // MARK: - Notifications

    private func requestNotificationPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }

    private func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body.isEmpty ? "(пустой ответ)" : body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

extension PermissionRequest: Identifiable {
    var id: String { toolCallSummary + String(UUID().uuidString.prefix(8)) }
}
