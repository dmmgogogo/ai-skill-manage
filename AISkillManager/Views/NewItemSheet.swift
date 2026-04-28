import SwiftUI

struct NewItemSheet: View {
    @Bindable var store: AppStore
    @Binding var isPresented: Bool

    @State private var selectedSourceKey: AppStore.SourceKey
    @State private var nameInput: String = ""
    @State private var errorMessage: String?

    init(store: AppStore, isPresented: Binding<Bool>) {
        self._store = Bindable(store)
        self._isPresented = isPresented
        let initial = store.selectedSourceKey ?? store.allSourceKeys.first ?? ""
        self._selectedSourceKey = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("新建条目")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("目标源").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $selectedSourceKey) {
                    ForEach(store.allSourceKeys, id: \.self) { key in
                        if let meta = store.sourceMeta(for: key) {
                            Text("\(meta.kind.displayName) — \(meta.scope.displayLabel)")
                                .tag(key)
                        }
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("名称").font(.caption).foregroundStyle(.secondary)
                TextField("例如：my-new-skill", text: $nameInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { create() }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("创建") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func create() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        Task { @MainActor in
            do {
                _ = try await store.createItem(name: trimmed, in: selectedSourceKey)
                isPresented = false
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
