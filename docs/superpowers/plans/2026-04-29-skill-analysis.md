# Skill Analysis Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ChatGPT-powered skill analysis with a right-side drawer, persistent cache, settings sheet, and version number in the sidebar.

**Architecture:** URLSession calls OpenAI chat/completions; results cached in `~/Library/Application Support/Triskill/analysis-cache.json` keyed by file path; `AnalysisStore` (@Observable) drives the drawer UI; `Preferences` extended with `apiKey`/`model` (backward-compatible via `decodeIfPresent`).

**Tech Stack:** SwiftUI, URLSession (no new packages), existing `PreferencesStore` pattern.

---

### Task 1: Extend Preferences with API settings (backward-compatible)

**Files:**
- Modify: `AISkillManager/Infrastructure/PreferencesStore.swift`
- Test: `AISkillManagerTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Read the current test file to understand patterns**

```bash
cat AISkillManagerTests/PreferencesStoreTests.swift
```

- [ ] **Step 2: Add `apiKey` and `model` to `Preferences` with backward-compatible decoding**

Replace the `Preferences` struct in `AISkillManager/Infrastructure/PreferencesStore.swift`:

```swift
struct Preferences: Codable {
    var projects: [Project] = []
    var apiKey: String = ""
    var model: String = "gpt-4o"

    init(projects: [Project] = [], apiKey: String = "", model: String = "gpt-4o") {
        self.projects = projects
        self.apiKey = apiKey
        self.model = model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
        apiKey   = try container.decodeIfPresent(String.self, forKey: .apiKey)   ?? ""
        model    = try container.decodeIfPresent(String.self, forKey: .model)    ?? "gpt-4o"
    }
}
```

- [ ] **Step 3: Add a test for backward-compatible decode**

In `AISkillManagerTests/PreferencesStoreTests.swift`, add:

```swift
func test_decode_legacy_json_without_api_fields() throws {
    // JSON without apiKey/model — simulates existing preferences.json before this feature
    let json = #"{"projects":[]}"#.data(using: .utf8)!
    let prefs = try JSONDecoder().decode(Preferences.self, from: json)
    XCTAssertEqual(prefs.apiKey, "")
    XCTAssertEqual(prefs.model, "gpt-4o")
    XCTAssertTrue(prefs.projects.isEmpty)
}

func test_roundtrip_with_api_fields() throws {
    var prefs = Preferences()
    prefs.apiKey = "sk-test"
    prefs.model  = "gpt-4o-mini"
    let data  = try JSONEncoder().encode(prefs)
    let back  = try JSONDecoder().decode(Preferences.self, from: data)
    XCTAssertEqual(back.apiKey, "sk-test")
    XCTAssertEqual(back.model,  "gpt-4o-mini")
}
```

- [ ] **Step 4: Build and run tests**

```bash
xcodebuild test -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add AISkillManager/Infrastructure/PreferencesStore.swift AISkillManagerTests/PreferencesStoreTests.swift
git commit -m "feat: extend Preferences with apiKey + model (backward-compatible)"
```

---

### Task 2: Create AnalysisCacheStore

**Files:**
- Create: `AISkillManager/Infrastructure/AnalysisCacheStore.swift`
- Create: `AISkillManagerTests/AnalysisCacheStoreTests.swift`

- [ ] **Step 1: Create `AnalysisCacheStore.swift`**

```swift
import Foundation

struct AnalysisEntry: Codable {
    var result: String
    var analyzedAt: Date
}

final class AnalysisCacheStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Triskill")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analysis-cache.json")
    }

    func entry(for path: String) -> AnalysisEntry? {
        loadAll()[path]
    }

    func save(entry: AnalysisEntry, for path: String) throws {
        var cache = loadAll()
        cache[path] = entry
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cache)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func loadAll() -> [String: AnalysisEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? decoder.decode([String: AnalysisEntry].self, from: data) else {
            return [:]
        }
        return cache
    }
}
```

- [ ] **Step 2: Create test file**

```swift
import XCTest
@testable import AISkillManager

final class AnalysisCacheStoreTests: XCTestCase {
    private var tempURL: URL!
    private var store: AnalysisCacheStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        store = AnalysisCacheStore(fileURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func test_entry_returns_nil_when_cache_empty() {
        XCTAssertNil(store.entry(for: "/some/path/SKILL.md"))
    }

    func test_save_and_load_roundtrip() throws {
        let entry = AnalysisEntry(result: "这是分析结果", analyzedAt: Date())
        try store.save(entry: entry, for: "/foo/SKILL.md")
        let loaded = store.entry(for: "/foo/SKILL.md")
        XCTAssertEqual(loaded?.result, "这是分析结果")
    }

    func test_multiple_entries_coexist() throws {
        try store.save(entry: AnalysisEntry(result: "A", analyzedAt: Date()), for: "/a/SKILL.md")
        try store.save(entry: AnalysisEntry(result: "B", analyzedAt: Date()), for: "/b/SKILL.md")
        XCTAssertEqual(store.entry(for: "/a/SKILL.md")?.result, "A")
        XCTAssertEqual(store.entry(for: "/b/SKILL.md")?.result, "B")
    }

    func test_overwrite_updates_entry() throws {
        try store.save(entry: AnalysisEntry(result: "old", analyzedAt: Date()), for: "/x/SKILL.md")
        try store.save(entry: AnalysisEntry(result: "new", analyzedAt: Date()), for: "/x/SKILL.md")
        XCTAssertEqual(store.entry(for: "/x/SKILL.md")?.result, "new")
    }
}
```

- [ ] **Step 3: Build and run tests**

```bash
xcodebuild test -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests pass including the 4 new ones.

- [ ] **Step 4: Commit**

```bash
git add AISkillManager/Infrastructure/AnalysisCacheStore.swift AISkillManagerTests/AnalysisCacheStoreTests.swift
git commit -m "feat: add AnalysisCacheStore for persisting skill analysis results"
```

---

### Task 3: Create AnalysisService

**Files:**
- Create: `AISkillManager/Infrastructure/AnalysisService.swift`

(No unit tests — requires live API key and network. Tested manually in Task 7.)

- [ ] **Step 1: Create `AnalysisService.swift`**

```swift
import Foundation

struct AnalysisService {
    let apiKey: String
    let model: String

    private static let systemPrompt = "请用中文分析这个 AI skill 文件，说明它的用途、触发时机和主要步骤，语言简洁。"

    func analyze(content: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user",   "content": content]
            ],
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AnalysisError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnalysisError.apiError(http.statusCode, body)
        }

        guard
            let json     = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices  = json["choices"] as? [[String: Any]],
            let message  = choices.first?["message"] as? [String: Any],
            let text     = message["content"] as? String
        else {
            throw AnalysisError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum AnalysisError: LocalizedError {
        case invalidResponse
        case apiError(Int, String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidResponse:       return "无效的服务器响应"
            case .apiError(let c, let b): return "API 错误 \(c)：\(b)"
            case .parseError:            return "解析响应失败"
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AISkillManager/Infrastructure/AnalysisService.swift
git commit -m "feat: add AnalysisService for OpenAI chat/completions"
```

---

### Task 4: Create AnalysisStore ViewModel

**Files:**
- Create: `AISkillManager/ViewModels/AnalysisStore.swift`

- [ ] **Step 1: Create `AnalysisStore.swift`**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class AnalysisStore {
    var isAnalyzing  = false
    var result:      String?
    var analyzedAt:  Date?
    var errorMessage: String?
    var showDrawer   = false

    private let cacheStore: AnalysisCacheStore
    private let prefsStore: PreferencesStore

    init(cacheStore: AnalysisCacheStore, prefsStore: PreferencesStore) {
        self.cacheStore = cacheStore
        self.prefsStore = prefsStore
    }

    static func makeDefault() -> AnalysisStore {
        AnalysisStore(
            cacheStore: AnalysisCacheStore(fileURL: AnalysisCacheStore.defaultURL()),
            prefsStore: PreferencesStore(fileURL: PreferencesStore.defaultURL())
        )
    }

    func analyze(item: SkillItem, forceRefresh: Bool = false) async {
        let path  = item.mainFileURL.path(percentEncoded: false)
        let prefs = prefsStore.load()

        if !forceRefresh, let cached = cacheStore.entry(for: path) {
            result       = cached.result
            analyzedAt   = cached.analyzedAt
            errorMessage = nil
            showDrawer   = true
            return
        }

        guard !prefs.apiKey.isEmpty else {
            errorMessage = "请先在设置中填写 OpenAI API Key"
            showDrawer   = true
            return
        }

        isAnalyzing  = true
        errorMessage = nil
        showDrawer   = true
        defer { isAnalyzing = false }

        let service = AnalysisService(apiKey: prefs.apiKey, model: prefs.model)
        do {
            let text  = try await service.analyze(content: item.rawContent)
            let entry = AnalysisEntry(result: text, analyzedAt: Date())
            try? cacheStore.save(entry: entry, for: path)
            result     = text
            analyzedAt = entry.analyzedAt
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        result       = nil
        analyzedAt   = nil
        errorMessage = nil
        // Keep showDrawer — let UI decide whether to close
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AISkillManager/ViewModels/AnalysisStore.swift
git commit -m "feat: add AnalysisStore view model"
```

---

### Task 5: Create SettingsSheet

**Files:**
- Create: `AISkillManager/Views/SettingsSheet.swift`

- [ ] **Step 1: Create `SettingsSheet.swift`**

```swift
import SwiftUI

private let kModelOptions = ["gpt-4.5", "gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    let prefsStore: PreferencesStore

    @State private var apiKey = ""
    @State private var model  = "gpt-4o"

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
        model  = prefs.model.isEmpty ? "gpt-4o" : prefs.model
    }

    private func save() {
        var prefs  = prefsStore.load()
        prefs.apiKey = apiKey
        prefs.model  = model
        try? prefsStore.save(prefs)
        isPresented = false
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AISkillManager/Views/SettingsSheet.swift
git commit -m "feat: add SettingsSheet for API key and model configuration"
```

---

### Task 6: Create AnalysisDrawer

**Files:**
- Create: `AISkillManager/Views/AnalysisDrawer.swift`

- [ ] **Step 1: Create `AnalysisDrawer.swift`**

```swift
import SwiftUI

struct AnalysisDrawer: View {
    @Bindable var analysisStore: AnalysisStore
    let item: SkillItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            if let date = analysisStore.analyzedAt {
                Divider()
                footer(date: date)
            }
        }
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Label("AI 分析", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if analysisStore.result != nil || analysisStore.errorMessage != nil {
                Button {
                    Task { await analysisStore.analyze(item: item, forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(analysisStore.isAnalyzing)
                .help("重新分析")
            }
            Button {
                analysisStore.showDrawer = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if analysisStore.isAnalyzing {
            VStack(spacing: 10) {
                ProgressView()
                Text("分析中…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 40)
        } else if let error = analysisStore.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        } else if let text = analysisStore.result {
            ScrollView {
                Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        } else {
            Text("点击工具栏「分析」按钮开始分析此 skill")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
        }
    }

    private func footer(date: Date) -> some View {
        Text("分析于 \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AISkillManager/Views/AnalysisDrawer.swift
git commit -m "feat: add AnalysisDrawer right-side panel"
```

---

### Task 7: Wire AnalysisStore into DetailView

**Files:**
- Modify: `AISkillManager/Views/DetailView.swift`

- [ ] **Step 1: Update `DetailView.swift`**

Replace the full file content with:

```swift
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
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AISkillManager/Views/DetailView.swift
git commit -m "feat: wire AnalysisStore + AnalysisDrawer into DetailView"
```

---

### Task 8: Update SidebarView — settings button + version number

**Files:**
- Modify: `AISkillManager/Views/SidebarView.swift`

- [ ] **Step 1: Update `SidebarView.swift`**

Add `@State private var showSettings = false` and a `PreferencesStore` instance. Wrap the existing `List` + `.alert` in a `VStack` and add the bottom bar. Add `.sheet(isPresented: $showSettings)`.

Replace the full file content with:

```swift
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
        panel.message = "选择一个项目根目录（包含 .claude/skills、.codex/skills、.cursor/rules 任一即可）"
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
```

- [ ] **Step 2: Build and run all tests**

```bash
xcodebuild test -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: All tests pass, BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AISkillManager/Views/SidebarView.swift
git commit -m "feat: add settings button + version number to sidebar bottom bar"
```

---

## Self-Review

**Spec coverage:**
- ✅ Manual analysis trigger — Task 7 (toolbar button)
- ✅ Chinese analysis output — Task 3 (system prompt)
- ✅ Right-side drawer — Tasks 6 + 7
- ✅ Persistent cache in Triskill app support dir — Tasks 2 + 4
- ✅ Force-refresh button in drawer — Task 6
- ✅ Settings Sheet (API key + model) — Task 5
- ✅ Settings button in sidebar bottom-left — Task 8
- ✅ Version number in sidebar bottom-left — Task 8
- ✅ Backward-compatible Preferences migration — Task 1
- ✅ Model options: gpt-4.5 / gpt-4o / gpt-4o-mini / gpt-4-turbo — Task 5
- ✅ "No API key" error shown in drawer — Task 4

**Placeholder scan:** None found.

**Type consistency:**
- `AnalysisEntry` defined in Task 2, used in Tasks 2, 4 ✅
- `AnalysisService` defined in Task 3, used in Task 4 ✅
- `AnalysisStore` defined in Task 4, used in Tasks 6, 7 ✅
- `AnalysisCacheStore` defined in Task 2, used in Task 4 ✅
- `SettingsSheet(isPresented:prefsStore:)` defined in Task 5, called in Task 8 ✅
- `AnalysisDrawer(analysisStore:item:)` defined in Task 6, called in Task 7 ✅
