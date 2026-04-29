import SwiftUI

private let kModelOptions = ["gpt-5.5", "gpt-5.4", "gpt-4.5", "gpt-4o", "gpt-4o-mini"]

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    let prefsStore: PreferencesStore

    @State private var apiKey = ""
    @State private var model  = "gpt-5.5"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("OpenAI API Key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecureField("sk-…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $model) {
                    ForEach(kModelOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear { loadPrefs() }
    }

    private func loadPrefs() {
        let prefs = prefsStore.load()
        apiKey = prefs.apiKey
        model  = prefs.model.isEmpty ? "gpt-5.5" : prefs.model
    }

    private func save() {
        var prefs    = prefsStore.load()
        prefs.apiKey = apiKey
        prefs.model  = model
        try? prefsStore.save(prefs)
        isPresented  = false
    }
}
