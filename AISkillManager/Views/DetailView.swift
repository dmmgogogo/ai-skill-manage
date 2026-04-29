import SwiftUI

struct DetailView: View {
    @Bindable var store: AppStore
    @Bindable var editor: DetailEditorVM

    @State private var analysisStore = AnalysisStore.makeDefault()
    @State private var saveError: String?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        Group {
            if let item = editor.boundItem {
                VStack(spacing: 0) {
                    toolbar(for: item)
                    Divider()
                    HStack(spacing: 0) {
                        TextEditor(text: $editor.editingContent)
                            .font(.system(size: 13, design: .monospaced))
                            .lineSpacing(2)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor))
                            .padding(.horizontal, 4)
                        if analysisStore.showDrawer {
                            Divider()
                            AnalysisDrawer(analysisStore: analysisStore, item: item)
                        }
                    }
                    statusBar(for: item)
                }
            } else {
                ContentUnavailableView("未选中条目",
                                       systemImage: "doc.text",
                                       description: Text("从左侧选择一个 skill 查看内容"))
            }
        }
        .onChange(of: store.currentItem) { _, newItem in
            analysisStore.reset()
            if let newItem {
                editor.bind(to: newItem)
            } else {
                editor.unbind()
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
        .alert("删除「\(editor.boundItem?.name ?? "")」？",
               isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("移到废纸篓", role: .destructive) {
                doDelete()
            }
        } message: {
            Text("条目会被移到 macOS 废纸篓，可在那里恢复。")
        }
        .alert("删除失败", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("好") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
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
                Task { await analysisStore.analyze(item: item) }
            } label: {
                if analysisStore.isAnalyzing {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Label("分析", systemImage: "sparkles")
                }
            }
            .disabled(analysisStore.isAnalyzing || item.rawContent.isEmpty)
            .help("用 AI 分析此 skill 的用途")
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
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            .help("移到废纸篓")
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

    private func doDelete() {
        guard let item = editor.boundItem else { return }
        Task { @MainActor in
            do {
                try await store.deleteItem(item)
                if let next = store.currentItem {
                    editor.bind(to: next)
                } else {
                    editor.unbind()
                }
            } catch {
                deleteError = (error as NSError).localizedDescription
            }
        }
    }
}
