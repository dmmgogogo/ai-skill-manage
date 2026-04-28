import SwiftUI

struct DetailView: View {
    @Bindable var store: AppStore

    var body: some View {
        if let item = store.currentItem {
            VStack(spacing: 0) {
                toolbar(for: item)
                Divider()
                ScrollView {
                    Text(item.rawContent)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
                .background(Color(nsColor: .textBackgroundColor))
                statusBar(for: item)
            }
        } else {
            ContentUnavailableView("未选中条目",
                                   systemImage: "doc.text",
                                   description: Text("从左侧选择一个 skill 查看内容"))
        }
    }

    @ViewBuilder
    private func toolbar(for item: SkillItem) -> some View {
        HStack(spacing: 8) {
            Text(item.mainFileURL.path(percentEncoded: false))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.mainFileURL])
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(item.mainFileURL.path(percentEncoded: false), forType: .string)
            } label: {
                Label("复制路径", systemImage: "doc.on.doc")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func statusBar(for item: SkillItem) -> some View {
        HStack(spacing: 18) {
            Text("UTF-8")
            Text(item.kind == .cursorRules ? "Markdown (Cursor MDC)" : "YAML + Markdown")
            Text("\(item.sizeBytes) bytes")
            Spacer()
            Text("只读 (M1)")
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Color.accentColor)
        .foregroundStyle(.white)
    }
}
