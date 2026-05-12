//
//  ACPChatApp.swift
//  ACPChat — thin iOS client for acp-router over WebSocket.
//
//  Entry point. Wires SwiftData container, injects ACPClient into the
//  environment, and presents the root NavigationSplitView.
//

import SwiftUI
import SwiftData

@main
struct ACPChatApp: App {
    // Persistent container: sessions and messages survive app relaunch.
    // SwiftData auto-migrates schema changes across versions.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            StoredSession.self,
            StoredMessage.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    // One shared network client across the whole app. It lives as long
    // as the process; reconnects automatically when the socket drops
    // (iPhone backgrounding, network switch, VPN flap).
    @State private var client = ACPClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(client)
                // HUD-тема построена под dark, в light фоны DS.surface/
                // bgSubtle становятся белыми и стеклянные панели сливаются
                // со скринами. Лочим dark на весь app.
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
