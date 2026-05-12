//
//  SessionListView.swift
//
//  REGHelp-styled sidebar list. Each session is a row card:
//    - 4px indigo left bar when active
//    - tag (bold), DG chip if mode == "dg", relative updated time
//    - monospaced session id preview (first 8 chars)
//    - swipe actions: rename, delete
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    let sessions: [StoredSession]
    @Binding var selectedSession: StoredSession?
    @Environment(\.modelContext) private var modelContext

    /// Router-side persisted sessions — chats that were created in other
    /// clients (Zed, previous iOS launches) and are still revivable via
    /// `session/load`. The drawer of "Discovered on router" at the top.
    var routerSessions: [PersistedRouterSession] = []
    /// Tap handler — parent (RootView) performs `session/load`, creates
    /// a StoredSession mirror, and selects it.
    var onAdoptRouterSession: (PersistedRouterSession) -> Void = { _ in }
    /// User-pulled refresh of the router list.
    var onRefreshRouterSessions: () -> Void = {}

    @State private var renameTarget: StoredSession?
    @State private var renameBuffer: String = ""

    /// Paths we've already adopted — dim them in the discovered list
    /// so the user doesn't try to re-import the same session twice.
    private var adoptedIds: Set<String> { Set(sessions.map { $0.id }) }

    var body: some View {
        Group {
            if sessions.isEmpty && routerSessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        // Не ставим сюда DS.bgSubtle — CyberpunkBackground рисуется
        // в RootView и должен просвечивать через список.
        .scrollContentBackground(.hidden)
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.large)
        .alert("Rename session", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Tag", text: $renameBuffer)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("OK") {
                if let t = renameTarget, !renameBuffer.isEmpty {
                    t.tag = renameBuffer
                    try? modelContext.save()
                }
                renameTarget = nil
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List(selection: $selectedSession) {
            if !routerSessions.isEmpty {
                Section {
                    ForEach(routerSessions) { rs in
                        routerRow(rs)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "externaldrive.badge.wifi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.P.s500)
                        Text("Discovered on router")
                            .font(DS.tTagSm)
                            .foregroundStyle(DS.P.s500)
                        Spacer()
                        Button { onRefreshRouterSessions() } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.P.s500)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !sessions.isEmpty {
                Section {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            row(session)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { delete(session) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                renameTarget = session
                                renameBuffer = session.tag
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(DS.primary)
                        }
                    }
                } header: {
                    if !routerSessions.isEmpty {
                        Text("Local chats")
                            .font(DS.tTagSm)
                            .foregroundStyle(DS.inkMuted)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func routerRow(_ rs: PersistedRouterSession) -> some View {
        let adopted = adoptedIds.contains(rs.routerSessionId)
        return Button {
            if !adopted { onAdoptRouterSession(rs) }
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(adopted ? Color.clear : DS.P.s500.opacity(0.6))
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                VStack(alignment: .leading, spacing: DS.s2) {
                    HStack(spacing: DS.s2) {
                        Text(rs.agentId.isEmpty ? "session" : rs.agentId)
                            .font(DS.body(15, weight: .semibold))
                            .foregroundStyle(adopted ? DS.inkFaint : DS.ink)
                        if !rs.currentModel.isEmpty {
                            RChip(text: rs.currentModel, color: .accent)
                        }
                        if adopted {
                            RChip(text: "adopted", color: .gray)
                        }
                        Spacer()
                    }
                    HStack(spacing: DS.s2) {
                        Text(rs.routerSessionId.prefix(8))
                            .font(DS.tTagSm)
                            .foregroundStyle(DS.inkFaint)
                        if let cwd = rs.cwd, !cwd.isEmpty {
                            Text("·")
                                .font(DS.tXs)
                                .foregroundStyle(DS.inkFaint)
                            Text(cwd)
                                .font(DS.tXs)
                                .foregroundStyle(DS.inkMuted)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        Spacer()
                        if rs.savedAt > 0 {
                            Text(Date(timeIntervalSince1970: rs.savedAt / 1000),
                                 style: .relative)
                                .font(DS.tXs)
                                .foregroundStyle(DS.inkMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                    .fill(DS.surface.opacity(adopted ? 0.4 : 0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DS.P.s500.opacity(adopted ? 0.15 : 0.55),
                                DS.P.a500.opacity(adopted ? 0.10 : 0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadowCard()
        }
        .buttonStyle(.plain)
        .disabled(adopted)
    }

    private func row(_ session: StoredSession) -> some View {
        let isActive = selectedSession?.id == session.id
        return HStack(spacing: 0) {
            Rectangle()
                .fill(isActive ? DS.primary : Color.clear)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading, spacing: DS.s2) {
                HStack(spacing: DS.s2) {
                    Text(session.tag)
                        .font(DS.body(15, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    if session.mode == "dg" {
                        RChip(text: "DG", color: .accent)
                    }
                    Spacer()
                }
                HStack(spacing: DS.s2) {
                    Text(session.id.prefix(8))
                        .font(DS.tTagSm)
                        .foregroundStyle(DS.inkFaint)
                    Text("·")
                        .font(DS.tXs)
                        .foregroundStyle(DS.inkFaint)
                    Text(session.updatedAt, style: .relative)
                        .font(DS.tXs)
                        .foregroundStyle(DS.inkMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                .fill(isActive ? DS.P.p50 : DS.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                .stroke(isActive ? DS.P.p200 : DS.hairline, lineWidth: 1)
        )
        .shadowCard()
    }

    private var emptyState: some View {
        VStack(spacing: DS.s3) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DS.inkFaint)
            Text("No sessions yet")
                .font(DS.tH3)
                .foregroundStyle(DS.ink)
            Text("Нажмите +, чтобы создать новую сессию.")
                .font(DS.tSm)
                .foregroundStyle(DS.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.s6)
    }

    private func delete(_ session: StoredSession) {
        if selectedSession?.id == session.id { selectedSession = nil }
        modelContext.delete(session)
        try? modelContext.save()
    }
}
