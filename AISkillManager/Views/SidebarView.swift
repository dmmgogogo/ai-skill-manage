import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore

    var body: some View {
        List(selection: Binding(
            get: { store.selectedSourceKey },
            set: { newValue in
                if let key = newValue {
                    store.selectSource(key)
                }
            }
        )) {
            Section("用户级") {
                ForEach(store.allSourceKeys, id: \.self) { key in
                    if let meta = store.sourceMeta(for: key) {
                        sidebarRow(key: key, meta: meta)
                            .tag(Optional(key))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
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
}
