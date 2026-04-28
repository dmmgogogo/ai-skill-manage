import SwiftUI

struct AppRoot: View {
    @State private var registry: ProjectRegistry
    @State private var store: AppStore
    @State private var editor: DetailEditorVM
    @State private var showNewItemSheet = false

    init() {
        let r = ProjectRegistry.makeDefault()
        let s = AppStore.makeDefault(registry: r)
        _registry = State(initialValue: r)
        _store = State(initialValue: s)
        _editor = State(initialValue: DetailEditorVM(store: s))
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, registry: registry)
        } content: {
            ItemListView(store: store)
        } detail: {
            DetailView(store: store, editor: editor)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .task {
            await store.loadAll()
            if let item = store.currentItem, editor.boundItem == nil {
                editor.bind(to: item)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshOnFocus() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewItemSheet = true
                } label: {
                    Label("新建", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showNewItemSheet) {
            NewItemSheet(store: store, isPresented: $showNewItemSheet)
        }
    }

    private func refreshOnFocus() async {
        let wasEditing = editor.isDirty
        await store.loadAll()
        if !wasEditing {
            if let item = store.currentItem {
                editor.bind(to: item)
            }
        }
    }
}
