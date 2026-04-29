import Foundation
import Observation

@Observable
@MainActor
final class AnalysisStore {
    var isAnalyzing:  Bool    = false
    var result:       String?
    var analyzedAt:   Date?
    var errorMessage: String?
    var showDrawer:   Bool    = false

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

    // 切换 skill 时调用：有缓存则立刻展示，没有则清空内容（抽屉保持打开）
    func switchItem(to item: SkillItem) {
        let path = item.mainFileURL.path(percentEncoded: false)
        if let cached = cacheStore.entry(for: path) {
            result       = cached.result
            analyzedAt   = cached.analyzedAt
            errorMessage = nil
        } else {
            result       = nil
            analyzedAt   = nil
            errorMessage = nil
        }
    }

    func reset() {
        result       = nil
        analyzedAt   = nil
        errorMessage = nil
    }
}
