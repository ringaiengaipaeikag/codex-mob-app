//
//  SettingsView.swift
//
//  Flowbite settings page pattern. Stacked FBCards, each with:
//    - title + descriptive subtitle
//    - FBTextField inputs with block labels
//    - FBButton row
//  Status shown as FBAlert.
//

import SwiftUI

struct SettingsView: View {
    @Binding var bridgeURL: String
    @Binding var bridgeToken: String
    @Binding var allowSelfSigned: Bool
    @Binding var cfAccessClientId: String
    @Binding var cfAccessClientSecret: String

    @Environment(ACPClient.self) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var probing: Bool = false
    @State private var lastMessage: String?
    @State private var lastKind: FBAlert.Kind = .info

    var body: some View {
        // Отказываемся от NavigationStack.toolbar — его ToolbarItem на iOS 26
        // всё равно получает glass capsule. Рисуем свой header вручную.
        VStack(spacing: 0) {
            customHeader
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s5) {
                    header
                    endpointCard
                    tlsCard
                    cfAccessCard
                    actionsCard
                    if let msg = lastMessage {
                        FBAlert(kind: lastKind, title: nil, text: msg)
                    }
                    helpCard
                }
                .padding(DS.s4)
            }
            .background(DS.surfaceAlt)
        }
        .background(DS.surfaceAlt.ignoresSafeArea())
    }

    private var customHeader: some View {
        HStack(spacing: DS.s3) {
            Text("Bridge settings")
                .font(DS.body(17, weight: .semibold))
                .foregroundStyle(DS.ink)
                .shadow(color: DS.P.s500.opacity(0.30), radius: 8, x: 0, y: 0)
            Spacer()
            // Done — glass capsule + cyan neon stroke + cyan glow. Так
            // автостекло iOS 26 ложится ровно внутрь, выглядит намеренно.
            Button { dismiss() } label: {
                Text("Done")
                    .font(DS.body(15, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.85)
                    )
                    .overlay(
                        Capsule(style: .continuous).stroke(
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
                    .shadow(color: DS.P.s500.opacity(0.40), radius: 8, x: 0, y: 0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.s4)
        .padding(.top, DS.s3)
        .padding(.bottom, DS.s3)
        .background(
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial).opacity(0.85)
                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.black.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.P.s500.opacity(0.0),
                                DS.P.s500.opacity(0.55),
                                DS.P.a500.opacity(0.45),
                                DS.P.s500.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .shadow(color: DS.P.s500.opacity(0.5), radius: 3, x: 0, y: 0)
            }
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Cards

    private var header: some View {
        FBCard(padding: DS.s5) {
            VStack(alignment: .leading, spacing: DS.s3) {
                HStack(spacing: DS.s2) {
                    FBBadge(text: "ACP/WS", color: .indigo, uppercase: true)
                    statusBadge
                    Spacer()
                }
                Text("WebSocket Bridge")
                    .font(DS.tH3)
                    .foregroundStyle(DS.ink)
                Text("Transport for the acp-router running on your machine. Expose it over Tailscale only.")
                    .font(DS.tBody)
                    .foregroundStyle(DS.inkMuted)
            }
        }
    }

    private var endpointCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionHeader("Endpoint",
                              sub: "URL path must be /acp. Port defaults to 8443.")
                FBTextField(
                    label: "URL",
                    placeholder: "wss://100.x.y.z:8443/acp",
                    text: $bridgeURL,
                    helper: "Tailscale MagicDNS or LAN IP + /acp",
                    keyboard: .URL,
                    mono: true
                )
                FBTextField(
                    label: "Bearer token",
                    placeholder: "value of ACP_WS_TOKEN",
                    text: $bridgeToken,
                    helper: "Compared with timingSafeEqual server-side",
                    secure: true,
                    mono: true
                )
            }
        }
    }

    private var tlsCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionHeader("Transport security",
                              sub: "Self-signed TLS is safe inside a Tailscale tailnet — do not enable on untrusted networks. With Cloudflare Tunnel you get a real cert, keep this off.")
                FBToggle(
                    title: "Allow self-signed TLS",
                    subtitle: "Bypasses certificate chain validation",
                    isOn: $allowSelfSigned
                )
            }
        }
    }

    private var cfAccessCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionHeader(
                    "Cloudflare Access (optional)",
                    sub: "Service token for Zero Trust Access in front of the tunnel. Leave empty when not using Access."
                )
                FBTextField(
                    label: "CF-Access-Client-Id",
                    placeholder: "xxxxxxxxxxxx.access",
                    text: $cfAccessClientId,
                    helper: "From Zero Trust → Access → Service Tokens",
                    mono: true
                )
                FBTextField(
                    label: "CF-Access-Client-Secret",
                    placeholder: "hex secret shown once on creation",
                    text: $cfAccessClientSecret,
                    helper: "Sent as header during WS handshake",
                    secure: true,
                    mono: true
                )
            }
        }
    }

    private var actionsCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionHeader("Actions", sub: nil)
                HStack(spacing: DS.s2) {
                    FBButton(
                        title: client.status == .connected ? "Reconnect" : "Connect",
                        icon: "bolt.fill",
                        variant: .primary,
                        size: .md,
                        fullWidth: true
                    ) { Task { await doConnect() } }

                    FBButton(
                        title: "Disconnect",
                        icon: "power",
                        variant: .alternative,
                        size: .md,
                        fullWidth: true
                    ) { Task { await client.disconnect() } }
                }
                FBButton(
                    title: probing ? "Testing…" : "Test (dry initialize)",
                    icon: "waveform.path.ecg",
                    variant: .outlinePrimary,
                    size: .md,
                    fullWidth: true
                ) { Task { await doTest() } }
                .disabled(probing)
            }
        }
    }

    private var helpCard: some View {
        FBCard(padding: DS.s4) {
            VStack(alignment: .leading, spacing: DS.s3) {
                sectionHeader("Notes", sub: nil)
                bullet("URL path must be /acp.")
                bullet("Port defaults to 8443 (override with ACP_WS_PORT).")
                bullet("For plain ws:// set ACP_WS_NO_TLS=1 server-side.")
                bullet("Server binds 127.0.0.1 by default; expose via tailnet IP.")
            }
        }
    }

    // MARK: - Small pieces

    private func sectionHeader(_ title: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DS.tH4).foregroundStyle(DS.ink)
            if let sub {
                Text(sub).font(DS.tSm).foregroundStyle(DS.inkMuted)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.s2) {
            Circle().fill(DS.inkMuted).frame(width: 4, height: 4).padding(.top, 7)
            Text(text).font(DS.tBody).foregroundStyle(DS.inkDim)
            Spacer(minLength: 0)
        }
    }

    private var statusBadge: some View {
        Group {
            switch client.status {
            case .connected:    FBBadge(text: "online",  color: .green, pill: true, icon: "circle.fill")
            case .connecting:   FBBadge(text: "connecting", color: .yellow, pill: true)
            case .error:        FBBadge(text: "error",   color: .red, pill: true, icon: "exclamationmark.circle.fill")
            case .disconnected: FBBadge(text: "offline", color: .red, pill: true)
            case .idle:         FBBadge(text: "idle",    color: .gray, pill: true)
            }
        }
    }

    // MARK: - Actions

    private func buildConfig(url: URL) -> WebSocketTransport.Config {
        .init(
            url: url,
            token: bridgeToken,
            allowSelfSignedTLS: allowSelfSigned,
            cfAccessClientId:     cfAccessClientId.isEmpty     ? nil : cfAccessClientId,
            cfAccessClientSecret: cfAccessClientSecret.isEmpty ? nil : cfAccessClientSecret
        )
    }

    private func doConnect() async {
        lastMessage = nil
        guard let url = URL(string: bridgeURL) else {
            lastKind = .danger; lastMessage = "invalid url"; return
        }
        guard !bridgeToken.isEmpty else {
            lastKind = .warning; lastMessage = "token is empty"; return
        }
        do {
            try await client.connect(buildConfig(url: url))
            lastKind = .success; lastMessage = "connect ok"
        } catch {
            lastKind = .danger; lastMessage = "connect failed: \(error.localizedDescription)"
        }
    }

    private func doTest() async {
        probing = true; defer { probing = false }
        lastMessage = nil
        guard let url = URL(string: bridgeURL) else {
            lastKind = .danger; lastMessage = "invalid url"; return
        }
        do {
            try await client.connect(buildConfig(url: url))
            lastKind = .success; lastMessage = "initialize ok"
            await client.disconnect()
        } catch {
            lastKind = .danger; lastMessage = "test failed: \(error.localizedDescription)"
        }
    }
}
