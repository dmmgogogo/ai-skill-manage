import SwiftUI

struct AppRoot: View {
    @State private var store = AppStore.makeDefault()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } content: {
            ItemListView(store: store)
        } detail: {
            DetailView(store: store)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .task {
            await store.loadAll()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.loadAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
