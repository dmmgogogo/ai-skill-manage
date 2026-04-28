import SwiftUI

struct DetailView: View {
    @Bindable var store: AppStore
    @Bindable var editor: DetailEditorVM

    @State private var saveError: String?

    var body: some View {
        Group {
            if let item = editor.boundItem {
                VStack(spacing: 0) {
                    toolbar(for: item)
                    Divider()
                    TextEditor(text: $editor.editingContent)
                        .font(.system(size: 13, design: .monospaced))
                        .lineSpacing(2)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .padding(.horizontal, 4)
                    statusBar(for: item)
                }
            } else {
                ContentUnavailableView("未选中条目",
                                       systemImage: "doc.text",
                                       description: Text("从左侧选择一个 skill 查看内容"))
            }
        }
        .onChange(of: store.currentItem) { _, newItem in
            if let newItem {
                editor.bind(to: newItem)
            }
        }
        .onAppear {
            if let item = store.currentItem, editor.boundItem == nil {
                editor.bind(to: item)
            }
        }
        .alert("保存失败", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好") { saveError = nil }
        } message: {
            Text(saveError ?? "")
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
            if editor.isDirty {
                Text("已修改")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.mainFileURL])
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(item.mainFileURL.path(percentEncoded: false), forType: .string)
            } label: {
                Label("复制路径", systemImage: "doc.on.doc")
            }
            Button {
                doSave()
            } label: {
                Label("保存", systemImage: "tray.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!editor.isDirty)
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
            Text(editor.isDirty ? "未保存" : "已保存")
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Color.accentColor)
        .foregroundStyle(.white)
    }

    private func doSave() {
        do {
            try editor.save()
        } catch {
            saveError = (error as NSError).localizedDescription
        }
    }
}
