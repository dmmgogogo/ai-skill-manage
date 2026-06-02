import SwiftUI
import AppKit

struct SidebarView: View {
    @Bindable var store: AppStore
    @Bindable var registry: ProjectRegistry

    @State private var addProjectError: String?
    @State private var showSettings = false

    private let prefsStore = PreferencesStore(fileURL: PreferencesStore.defaultURL())
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { store.selectedSourceKey },
                set: { newValue in
                    if let key = newValue { store.selectSource(key) }
                }
            )) {
                Section("用户级") {
                    ForEach(userSourceKeys, id: \.self) { key in
                        if let meta = store.sourceMeta(for: key) {
                            sidebarRow(key: key, meta: meta)
                                .tag(Optional(key))
                        }
                    }
                }

                ForEach(registry.projects) { project in
                    Section {
                        ForEach(projectSourceKeys(for: project), id: \.self) { key in
                            if let meta = store.sourceMeta(for: key) {
                                sidebarRow(key: key, meta: meta)
                                    .tag(Optional(key))
                            }
                        }
                    } header: {
                        HStack {
                            Text("项目: \(project.name)")
                            Spacer()
                            Button(role: .destructive) {
                                removeProject(project.id)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("移除项目（不删除磁盘上的目录）")
                        }
                    }
                }

                Section {
                    Button {
                        presentOpenPanel()
                    } label: {
                        Label("添加项目目录", systemImage: "plus.rectangle.on.folder")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            .alert("添加项目失败",
                   isPresented: Binding(get: { addProjectError != nil },
                                        set: { if !$0 { addProjectError = nil } })) {
                Button("好") { addProjectError = nil }
            } message: {
                Text(addProjectError ?? "")
            }

            Divider()
            bottomBar
        }
        .frame(minWidth: 200)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(isPresented: $showSettings, prefsStore: prefsStore)
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
            Text("v\(appVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var userSourceKeys: [AppStore.SourceKey] {
        store.allSourceKeys.filter {
            if let meta = store.sourceMeta(for: $0), meta.scope == .user { return true }
            return false
        }
    }

    private func projectSourceKeys(for project: Project) -> [AppStore.SourceKey] {
        store.allSourceKeys.filter { key in
            guard let meta = store.sourceMeta(for: key) else { return false }
            if case .project(let p) = meta.scope, p.id == project.id { return true }
            return false
        }
    }

    @ViewBuilder
    private func sidebarRow(key: AppStore.SourceKey, meta: (kind: SourceKind, scope: SourceScope)) -> some View {
        HStack {
            Image(systemName: meta.kind.iconSymbol)
                .frame(width: 18)
            Text(meta.kind.displayName)
            Spacer()
            if store.loadErrors[key] != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(store.loadErrors[key] ?? "")
            }
            Text("\(store.itemsBySource[key]?.count ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择一个项目根目录（包含 .claude/skills、.codex/skills、.cursor/rules、AGENTS.md 任一即可）"
        panel.prompt = "添加"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let project = Project(name: url.lastPathComponent, path: url)
        Task { @MainActor in
            do {
                try await store.addProject(project)
            } catch {
                addProjectError = (error as NSError).localizedDescription
            }
        }
    }

    private func removeProject(_ id: UUID) {
        Task { @MainActor in
            try? await store.removeProject(projectID: id)
        }
    }
}
