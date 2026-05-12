//
//  RootView.swift
//
//  Top-level NavigationSplitView. Cyberpunk-HUD chrome:
//    - фон — CyberpunkBackground (сетка + glow + scanlines)
//    - topbar: connection pill в glass + settings-gear в glass-круге с
//              неоновым stroke + заголовок "Sessions" с cyan-glow shadow
//    - bottombar: "New Session" с cyan-glow halo
//    - iOS 26 всё равно клеит Liquid Glass вокруг Button/RButton — мы
//      НЕ воюем с ним: подбираем свои неоновые обводки/свечения в тех же
//      corner-radius, чтобы стекло выглядело как часть нашего стиля.
//    - autoconnect на первый запуск + при возврате из background
//      (scenePhase == .active), если bridge.url и bridge.token заданы.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(ACPClient.self) private var client
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \StoredSession.updatedAt, order: .reverse)
    private var sessions: [StoredSession]

    @AppStorage("bridge.url") private var bridgeURL: String = ""
    @AppStorage("bridge.token") private var bridgeToken: String = ""
    @AppStorage("bridge.allowSelfSigned") private var allowSelfSigned: Bool = true
    // Cloudflare Access service token (optional, empty = not using Access).
    @AppStorage("cf.clientId") private var cfAccessClientId: String = ""
    @AppStorage("cf.clientSecret") private var cfAccessClientSecret: String = ""

    @State private var selectedSession: StoredSession?
    @State private var showSettings = false

    // Router-side persisted sessions discovered via router/listPersistedSessions.
    @State private var routerSessions: [PersistedRouterSession] = []

    var body: some View {
        NavigationSplitView {
            SessionListView(
                sessions: sessions,
                selectedSession: $selectedSession,
                routerSessions: routerSessions,
                onAdoptRouterSession: { rs in
                    Task { await adoptRouterSession(rs) }
                },
                onRefreshRouterSessions: {
                    Task { await refreshRouterSessions() }
                }
            )
            // Полностью прячем системный navbar/bottomBar/tabBar.
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .bottomBar)
            .toolbar(.hidden, for: .tabBar)
            // Киберпанк-подложка под весь список.
            .background(CyberpunkBackground().ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { customTopbar }
            .safeAreaInset(edge: .bottom, spacing: 0) { customBottombar }
        } detail: {
            if let session = selectedSession {
                ChatView(session: session)
            } else {
                emptyDetail
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                bridgeURL: $bridgeURL,
                bridgeToken: $bridgeToken,
                allowSelfSigned: $allowSelfSigned,
                cfAccessClientId: $cfAccessClientId,
                cfAccessClientSecret: $cfAccessClientSecret
            )
        }
        .task { await autoConnectIfConfigured() }
        // Возврат из background — тихий переподключ, если конфиг есть.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await autoConnectIfConfigured()
                    await refreshRouterSessions()
                }
            }
        }
        // При появлении connected статуса — подтягиваем router-chats.
        .onChange(of: client.status) { _, s in
            if case .connected = s {
                Task { await refreshRouterSessions() }
            }
        }
    }

    // MARK: - Custom HUD chrome (accept glass, style around it)

    private var customTopbar: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            HStack(spacing: DS.s3) {
                // Connection pill — та же высота 44pt что и у шестерёнки,
                // такая же стеклянная подложка (ultraThinMaterial 0.85) и
                // градиентный stroke в стиле HUD (status-hue → magenta). Без
                // этого pill казалась «висящей в воздухе» рядом с круглой
                // gear-иконкой — не матчились ни размер, ни материал.
                ConnectionBadge(status: client.status)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.85)
                    )
                    .overlay(
                        Capsule(style: .continuous).stroke(
                            LinearGradient(
                                colors: [
                                    badgeStroke,
                                    DS.P.a500.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: badgeGlow, radius: 10, x: 0, y: 0)

                Spacer()

                // Settings gear — glass-круг с cyan/magenta неоновым
                // градиентом по обводке + outer glow. Стеклянная капсула
                // от iOS 26 садится ровно внутрь Circle stroke'а.
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(DS.ink)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.85)
                        )
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [
                                        DS.P.s500.opacity(0.85),
                                        DS.P.a500.opacity(0.45)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        )
                        .shadow(color: DS.P.s500.opacity(0.45), radius: 10, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            Text("Sessions")
                .font(DS.body(32, weight: .bold))
                .foregroundStyle(DS.ink)
                // Cyan neon glow — делает заголовок частью HUD-темы.
                .shadow(color: DS.P.s500.opacity(0.40), radius: 14, x: 0, y: 0)
        }
        .padding(.horizontal, DS.s4)
        .padding(.top, DS.s2)
        .padding(.bottom, DS.s3)
        .background(
            topPanelBackground.ignoresSafeArea(edges: .top)
        )
    }

    private var customBottombar: some View {
        HStack {
            // Primary action — RButton (indigo capsule). iOS 26 ставит
            // вокруг Liquid Glass halo — мы добавляем cyan outer glow,
            // чтобы halo выглядел как намеренный неон, а не чужой chrome.
            RButton(
                title: "New Session",
                icon: "plus.message.fill",
                variant: .primary,
                size: .md,
                fullWidth: true
            ) {
                Task { await createNewSession() }
            }
            .disabled(client.status != .connected)
            .shadow(color: DS.P.s500.opacity(0.40), radius: 12, x: 0, y: 0)
            .shadow(color: DS.P.a500.opacity(0.20), radius: 18, x: 0, y: 0)
        }
        .padding(.horizontal, DS.s4)
        .padding(.top, DS.s3)
        .padding(.bottom, DS.s3)
        .background(
            bottomPanelBackground.ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Panel backgrounds (thin material + neon divider)

    private var topPanelBackground: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Нижняя неоновая линия — чистый HUD divider.
            neonDivider
        }
    }

    private var bottomPanelBackground: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Верхняя неоновая линия — отделяет панель от транскрипта.
            neonDivider
        }
    }

    private var neonDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        DS.P.s500.opacity(0.0),
                        DS.P.s500.opacity(0.60),
                        DS.P.a500.opacity(0.50),
                        DS.P.s500.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .shadow(color: DS.P.s500.opacity(0.5), radius: 3, x: 0, y: 0)
    }

    // MARK: - Badge neon colour map

    private var badgeStroke: Color {
        switch client.status {
        case .connected:    return Color.green.opacity(0.70)
        case .connecting:   return Color.yellow.opacity(0.70)
        case .error,
             .disconnected: return Color.red.opacity(0.70)
        case .idle:         return Color.gray.opacity(0.55)
        }
    }

    private var badgeGlow: Color {
        switch client.status {
        case .connected:    return Color.green.opacity(0.40)
        case .connecting:   return Color.yellow.opacity(0.40)
        case .error,
             .disconnected: return Color.red.opacity(0.40)
        case .idle:         return Color.clear
        }
    }

    // MARK: - Detail placeholder

    private var emptyDetail: some View {
        VStack(spacing: DS.s4) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DS.inkFaint)
            Text("Select a session")
                .font(DS.tH2)
                .foregroundStyle(DS.ink)
                .shadow(color: DS.P.s500.opacity(0.3), radius: 10, x: 0, y: 0)
            Text("Или создайте новую. Убедитесь, что bridge доступен по Tailscale.")
                .font(DS.tSm)
                .foregroundStyle(DS.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CyberpunkBackground().ignoresSafeArea())
    }

    // MARK: - Connection / session actions

    private func autoConnectIfConfigured() async {
        // Стартуем только если idle/disconnected/error — не рвём активное.
        let shouldConnect: Bool
        switch client.status {
        case .idle, .disconnected, .error: shouldConnect = true
        case .connecting, .connected:      shouldConnect = false
        }
        guard shouldConnect,
              let url = URL(string: bridgeURL),
              !bridgeToken.isEmpty
        else { return }

        let config = WebSocketTransport.Config(
            url: url,
            token: bridgeToken,
            allowSelfSignedTLS: allowSelfSigned,
            cfAccessClientId:     cfAccessClientId.isEmpty     ? nil : cfAccessClientId,
            cfAccessClientSecret: cfAccessClientSecret.isEmpty ? nil : cfAccessClientSecret
        )
        try? await client.connect(config)
    }

    private func createNewSession() async {
        do {
            let sid = try await client.newSession(cwd: "/path/to/project")
            let session = StoredSession(id: sid, tag: "session-\(Date().formatted(.dateTime.hour().minute()))")
            modelContext.insert(session)
            try? modelContext.save()
            selectedSession = session
        } catch {
            print("newSession failed: \(error)")
        }
    }

    // MARK: - Router-side sessions

    /// Pull the router's persisted-sessions list (from data/sessions.json)
    /// so the user can see chats started in other clients (Zed, previous
    /// iOS launch). Soft-fails — if we're not connected yet, ignore.
    private func refreshRouterSessions() async {
        guard client.status == .connected else { return }
        do {
            let fresh = try await client.listRouterSessions()
            // Sort by savedAt desc — most recent first.
            self.routerSessions = fresh.sorted { $0.savedAt > $1.savedAt }
        } catch {
            print("listRouterSessions failed: \(error)")
        }
    }

    /// User tapped a "Discovered on router" row → resurrect the session
    /// via session/load (router-side lazy-revive) and mirror it as a
    /// local StoredSession so it shows up in the primary list.
    private func adoptRouterSession(_ rs: PersistedRouterSession) async {
        let cwd = rs.cwd ?? "/path/to/project"
        do {
            try await client.loadSession(routerSessionId: rs.routerSessionId, cwd: cwd)
        } catch {
            // Soft-fail: loadSession may 404 if the downstream agent
            // process (claude-acp) is no longer alive. Still create the
            // local mirror — ChatView will retry loadSession on appear.
            print("loadSession on adopt soft-fail: \(error)")
        }
        // Avoid dup if already present (concurrent adopt taps).
        if !sessions.contains(where: { $0.id == rs.routerSessionId }) {
            let tag: String
            if !rs.currentModel.isEmpty {
                tag = "\(rs.agentId.isEmpty ? "router" : rs.agentId) · \(rs.currentModel)"
            } else {
                tag = rs.agentId.isEmpty ? "router session" : rs.agentId
            }
            let stored = StoredSession(id: rs.routerSessionId, tag: tag)
            // Preserve DG mode heuristic — we don't know it from router side
            // so default to the plain path. User can still type chat commands.
            modelContext.insert(stored)
            try? modelContext.save()
            selectedSession = stored
        } else if let existing = sessions.first(where: { $0.id == rs.routerSessionId }) {
            selectedSession = existing
        }
    }
}

// MARK: - Connection badge (glass-only, no inner chip)
//
// Раньше здесь был RChip — а он сам рисует внутреннюю Capsule с tinted
// bg. Поверх мы оборачивали ещё одной стеклянной Capsule → получались
// две капсулы разной ширины, внутренняя была меньше и «висела» в центре
// HUD-пилюли. Теперь рисуем плоско: только dot-индикатор в цвет статуса
// и подпись — без внутреннего фона. Внешняя стеклянная Capsule в RootView
// остаётся единственным «корпусом» пилюли.

struct ConnectionBadge: View {
    let status: ACPClient.ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(dotColor)
            Text(label)
                .font(DS.body(13, weight: .semibold))
                .foregroundStyle(DS.ink)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var label: String {
        switch status {
        case .connected:    return "online"
        case .connecting:   return "connecting"
        case .error:        return "error"
        case .disconnected: return "offline"
        case .idle:         return "idle"
        }
    }

    private var iconName: String {
        switch status {
        case .connected:    return "circle.fill"
        case .connecting:   return "dot.radiowaves.left.and.right"
        case .error:        return "exclamationmark.circle.fill"
        case .disconnected: return "wifi.slash"
        case .idle:         return "circle.dashed"
        }
    }

    private var dotColor: Color {
        switch status {
        case .connected:    return Color.green
        case .connecting:   return Color.yellow
        case .error,
             .disconnected: return Color.red
        case .idle:         return Color.gray
        }
    }
}
