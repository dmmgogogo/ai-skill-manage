import SwiftUI

struct ItemListView: View {
    @Bindable var store: AppStore

    private var items: [SkillItem] {
        guard let key = store.selectedSourceKey else { return [] }
        return store.itemsBySource[key] ?? []
    }

    var body: some View {
        List(selection: $store.selectedItemID) {
            ForEach(items) { item in
                row(for: item)
                    .tag(Optional(item.id))
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
        .frame(minWidth: 280)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("没有条目",
                                       systemImage: "tray",
                                       description: Text("此源下还没有 skill 文件"))
            }
        }
    }

    @ViewBuilder
    private func row(for item: SkillItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if !item.description.isEmpty {
                Text(item.description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                Text(item.scope.displayLabel)
                    .font(.system(size: 10))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(item.fileModifiedAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if item.hasSubdirectories {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
