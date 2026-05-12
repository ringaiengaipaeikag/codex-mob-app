//
//  FileDrawer.swift
//
//  Mini file manager that hangs off the chat bar. Collapsible panel —
//  when open, shows a lazy tree of the project's filesystem (resolved
//  through the bridge-side `fs/list` custom method so we stay inside
//  the ACP_FS_ROOTS allowlist). Tap a row:
//    • directory   → expand / collapse (lazy children fetch)
//    • file        → toggle selection for inclusion in the next prompt
//
//  Selected files get embedded into the outgoing prompt as fenced code
//  blocks with path headers. This keeps DG agents' context fresh with
//  real source without having to fight attachment routing.
//

import SwiftUI

// MARK: - Model

/// One node in the browsed tree. Children are lazily fetched.
@Observable
@MainActor
final class FSNode: Identifiable, Hashable {
    let path: String
    let name: String
    let isDir: Bool
    var size: Int64
    var mtime: Double

    var isExpanded: Bool = false
    var isLoading: Bool = false
    var error: String?
    var children: [FSNode] = []

    init(entry: FSEntry) {
        self.path = entry.path
        self.name = entry.name
        self.isDir = entry.isDir
        self.size = entry.size
        self.mtime = entry.mtime
    }

    /// Synthetic root: we know the path only, children will come from fs/list.
    init(root path: String) {
        self.path = path
        self.name = (path.split(separator: "/").last.map(String.init)) ?? path
        self.isDir = true
        self.size = 0
        self.mtime = 0
    }

    nonisolated static func == (lhs: FSNode, rhs: FSNode) -> Bool {
        lhs.path == rhs.path
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

/// Viewmodel — owns the tree state + selected set. Lives on ChatView
/// so selection persists across drawer open/close and is read at send.
@Observable
@MainActor
final class FileDrawerModel {
    /// Tree roots the user can browse. Seeded from ACP_FS_ROOTS on the
    /// bridge; we ask for "/path/to/project" by default.
    var roots: [FSNode]

    /// Paths of files the user marked for inclusion in the next prompt.
    var selected: Set<String> = []

    /// Transient error (surface in drawer header).
    var lastError: String?

    init(rootPaths: [String] = ["/path/to/project"]) {
        self.roots = rootPaths.map(FSNode.init(root:))
    }

    /// Populate (or refresh) one directory node's children via fs/list.
    func load(_ node: FSNode, using client: ACPClient) async {
        guard node.isDir else { return }
        node.isLoading = true
        node.error = nil
        defer { node.isLoading = false }
        do {
            let res = try await client.fsList(path: node.path)
            // Directories first, then files; both alphabetised. Keeps the
            // tree legible when a dir has hundreds of entries.
            let sorted = res.entries.sorted { a, b in
                if a.isDir != b.isDir { return a.isDir && !b.isDir }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            node.children = sorted.map(FSNode.init(entry:))
        } catch {
            node.error = error.localizedDescription
            lastError = "fs/list \(node.path): \(error.localizedDescription)"
        }
    }

    func toggleSelect(_ node: FSNode) {
        if node.isDir { return }
        if selected.contains(node.path) {
            selected.remove(node.path)
        } else {
            selected.insert(node.path)
        }
    }

    func isSelected(_ node: FSNode) -> Bool { selected.contains(node.path) }

    func clear() { selected.removeAll() }

    /// Read every selected file through fs/read and format it as a
    /// concatenated markdown block, so downstream agents see the
    /// content with language hints and path headers.
    ///
    /// Silently skips unreadable files (too-large, denied by allowlist)
    /// but includes a warning comment so the user knows.
    func buildContextBlock(using client: ACPClient) async -> String {
        guard !selected.isEmpty else { return "" }
        var out: [String] = ["", "<!-- attached project files -->"]
        for path in selected.sorted() {
            do {
                let r = try await client.fsRead(path: path)
                let lang = Self.language(for: path)
                out.append("")
                out.append("### `\(r.path)`")
                out.append("```\(lang)")
                out.append(r.content)
                out.append("```")
            } catch {
                out.append("")
                out.append("> ⚠ failed to read `\(path)`: \(error.localizedDescription)")
            }
        }
        return out.joined(separator: "\n")
    }

    /// Map extension → fenced-code language tag. Keeps DG syntax
    /// highlighting happy on the transcript side (ChatMarkdown).
    static func language(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":                     return "swift"
        case "ts", "tsx":                 return "typescript"
        case "js", "jsx", "mjs", "cjs":   return "javascript"
        case "py":                        return "python"
        case "rs":                        return "rust"
        case "go":                        return "go"
        case "c", "h":                    return "c"
        case "cc", "cpp", "cxx", "hpp":   return "cpp"
        case "java":                      return "java"
        case "kt", "kts":                 return "kotlin"
        case "m", "mm":                   return "objectivec"
        case "rb":                        return "ruby"
        case "sh", "bash", "zsh":         return "bash"
        case "json":                      return "json"
        case "yml", "yaml":               return "yaml"
        case "toml":                      return "toml"
        case "md", "markdown":            return "markdown"
        case "html", "htm":               return "html"
        case "css", "scss", "less":       return "css"
        case "sql":                       return "sql"
        case "xml":                       return "xml"
        case "dart":                      return "dart"
        case "lua":                       return "lua"
        case "s", "asm":                  return "asm"
        default:                          return ""
        }
    }
}

// MARK: - View

/// Collapsible drawer that sits between the attachment preview and the
/// input bar in ChatView. When closed, renders as a compact summary
/// chip; when open, fills the available height of the bottom section.
struct FileDrawer: View {
    @Bindable var model: FileDrawerModel
    @Environment(ACPClient.self) private var client

    /// Parent controls visibility. `true` = panel body is shown.
    @Binding var isOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if isOpen {
                Divider().background(DS.hairline.opacity(0.4))
                content
                    .frame(maxHeight: 320)
            }
        }
        .background(drawerBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.P.s500.opacity(isOpen ? 0.55 : 0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, DS.s3)
        .padding(.vertical, DS.s2)
        .shadow(color: DS.P.s500.opacity(isOpen ? 0.25 : 0), radius: 8, x: 0, y: 0)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.P.s500)
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    Text("Project files")
                        .font(DS.body(13, weight: .semibold))
                        .foregroundStyle(DS.ink)
                    if !model.selected.isEmpty {
                        Text("\(model.selected.count) selected")
                            .font(DS.tXs)
                            .foregroundStyle(DS.P.p500)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(DS.P.p500.opacity(0.18))
                            )
                            .overlay(
                                Capsule().stroke(DS.P.p500.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if !model.selected.isEmpty {
                Button {
                    model.clear()
                } label: {
                    Text("Clear")
                        .font(DS.tXs)
                        .foregroundStyle(DS.P.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().stroke(DS.P.red.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(model.roots) { root in
                    FSNodeRowsView(node: root, depth: 0, model: model)
                        .environment(client)
                }
                if let err = model.lastError {
                    Text(err)
                        .font(DS.tXs)
                        .foregroundStyle(DS.P.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Backdrop

    private var drawerBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Formatting

    private static func prettySize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Recursive node rows
//
// Why a separate struct and not a @ViewBuilder func: Swift can't
// infer `some View` for a function that recursively returns itself
// ("opaque return type defined in terms of itself"). Putting the
// recursion into a named struct breaks the cycle — the type refers
// to `FSNodeRowsView` explicitly, not to `some View`.

struct FSNodeRowsView: View {
    @Bindable var node: FSNode
    let depth: Int
    @Bindable var model: FileDrawerModel
    @Environment(ACPClient.self) private var client

    var body: some View {
        row
        if node.isDir && node.isExpanded {
            ForEach(node.children) { child in
                FSNodeRowsView(node: child, depth: depth + 1, model: model)
            }
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            if depth > 0 {
                Rectangle()
                    .fill(DS.hairline.opacity(0.4))
                    .frame(width: 1)
                    .padding(.leading, CGFloat(depth) * 12)
            } else {
                Spacer().frame(width: 4)
            }

            if node.isDir {
                Button {
                    Task { await toggle() }
                } label: {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.inkMuted)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    model.toggleSelect(node)
                } label: {
                    Image(systemName: model.isSelected(node) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(model.isSelected(node) ? DS.P.s500 : DS.inkFaint)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: Self.icon(for: node))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(node.isDir ? DS.P.p500 : DS.inkMuted)
                .frame(width: 14)

            Text(node.name)
                .font(node.isDir ? DS.body(13, weight: .semibold) : DS.tCodeSm)
                .foregroundStyle(DS.ink)
                .lineLimit(1)

            if node.isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .tint(DS.P.s500)
            }

            Spacer(minLength: 4)

            if !node.isDir && node.size > 0 {
                Text(Self.prettySize(node.size))
                    .font(DS.tXs)
                    .foregroundStyle(DS.inkFaint)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isDir {
                Task { await toggle() }
            } else {
                model.toggleSelect(node)
            }
        }
        .background(
            model.isSelected(node)
                ? DS.P.s500.opacity(0.08)
                : Color.clear
        )
    }

    private func toggle() async {
        if !node.isExpanded && node.children.isEmpty {
            await model.load(node, using: client)
        }
        withAnimation(.easeOut(duration: 0.15)) {
            node.isExpanded.toggle()
        }
    }

    private static func icon(for node: FSNode) -> String {
        if node.isDir {
            return node.isExpanded ? "folder.fill" : "folder"
        }
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "ts", "tsx", "js", "jsx", "py", "rs", "go", "c", "h", "cc", "cpp", "m", "mm":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml":
            return "curlybraces"
        case "md", "markdown", "txt":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp":
            return "photo"
        case "pdf":
            return "doc.richtext"
        default:
            return "doc"
        }
    }

    private static func prettySize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }
}
