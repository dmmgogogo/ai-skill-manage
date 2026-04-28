import Foundation
import Observation

@Observable
final class AppStore {
    typealias SourceKey = String

    static func sourceKey(kind: SourceKind, scope: SourceScope) -> SourceKey {
        "\(kind.rawValue):\(scope.key)"
    }

    private let repos: [SkillRepository]

    var itemsBySource: [SourceKey: [SkillItem]] = [:]
    var selectedSourceKey: SourceKey?
    var selectedItemID: SkillItemID?
    var isLoading = false
    var loadErrors: [SourceKey: String] = [:]

    init(repos: [SkillRepository]) {
        self.repos = repos
    }

    static func makeDefault() -> AppStore {
        AppStore(repos: [
            ClaudeSkillsRepo(),
            CodexSkillsRepo(),
            CursorSkillsRepo(),
            CursorRulesRepo(),
        ])
    }

    var currentItem: SkillItem? {
        guard let id = selectedItemID,
              let key = selectedSourceKey,
              let items = itemsBySource[key] else { return nil }
        return items.first { $0.id == id }
    }

    var allSourceKeys: [SourceKey] {
        repos.map { Self.sourceKey(kind: $0.kind, scope: $0.scope) }
    }

    func sourceMeta(for key: SourceKey) -> (kind: SourceKind, scope: SourceScope)? {
        guard let repo = repos.first(where: { Self.sourceKey(kind: $0.kind, scope: $0.scope) == key }) else {
            return nil
        }
        return (repo.kind, repo.scope)
    }

    @MainActor
    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        var grouped: [SourceKey: [SkillItem]] = [:]
        var errors: [SourceKey: String] = [:]

        for repo in repos {
            let key = Self.sourceKey(kind: repo.kind, scope: repo.scope)
            do {
                let items = try repo.listAll()
                grouped[key] = items
            } catch {
                grouped[key] = []
                errors[key] = String(describing: error)
            }
        }

        itemsBySource = grouped
        loadErrors = errors

        if selectedSourceKey == nil {
            if let firstKey = repos
                .map({ Self.sourceKey(kind: $0.kind, scope: $0.scope) })
                .first(where: { (grouped[$0]?.isEmpty == false) })
            {
                selectSource(firstKey)
            }
        }
    }

    func selectSource(_ key: SourceKey) {
        selectedSourceKey = key
        selectedItemID = itemsBySource[key]?.first?.id
    }
}
