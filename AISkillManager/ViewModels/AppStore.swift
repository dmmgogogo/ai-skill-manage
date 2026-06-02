import Foundation
import Observation

@Observable
@MainActor
final class AppStore {
    typealias SourceKey = String

    static func sourceKey(kind: SourceKind, scope: SourceScope) -> SourceKey {
        "\(kind.rawValue):\(scope.key)"
    }

    private(set) var repos: [SkillRepository]
    private let registry: ProjectRegistry?

    var itemsBySource: [SourceKey: [SkillItem]] = [:]
    var selectedSourceKey: SourceKey?
    var selectedItemID: SkillItemID?
    var isLoading = false
    var loadErrors: [SourceKey: String] = [:]

    init(repos: [SkillRepository], registry: ProjectRegistry? = nil) {
        self.repos = repos
        self.registry = registry
        if let registry {
            for project in registry.projects {
                self.repos.append(contentsOf: Self.makeProjectRepos(for: project))
            }
        }
    }

    static func makeDefault(registry: ProjectRegistry? = nil) -> AppStore {
        AppStore(
            repos: [
                ClaudeSkillsRepo(),
                CodexSkillsRepo(),
                CursorSkillsRepo(),
                CursorRulesRepo(),
                AgentsMdRepo(),
            ],
            registry: registry
        )
    }

    static func makeProjectRepos(for project: Project) -> [SkillRepository] {
        let scope: SourceScope = .project(project)
        return [
            DirectorySkillRepoBase(kind: .claudeSkills, scope: scope, root: project.path.appendingPathComponent(".claude/skills")),
            DirectorySkillRepoBase(kind: .codexSkills,  scope: scope, root: project.path.appendingPathComponent(".codex/skills")),
            DirectorySkillRepoBase(kind: .cursorSkills, scope: scope, root: project.path.appendingPathComponent(".cursor/skills")),
            CursorRulesRepo(scope: scope, root: project.path.appendingPathComponent(".cursor/rules")),
            AgentsMdRepo(scope: scope, projectRoot: project.path),
        ]
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

    func updateItem(_ updated: SkillItem) {
        let key = Self.sourceKey(kind: updated.kind, scope: updated.scope)
        guard var items = itemsBySource[key] else { return }
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return }
        items[idx] = updated
        itemsBySource[key] = items
    }

    func repository(for item: SkillItem) -> SkillRepository? {
        let key = Self.sourceKey(kind: item.kind, scope: item.scope)
        return repos.first { Self.sourceKey(kind: $0.kind, scope: $0.scope) == key }
    }

    func repository(forSourceKey key: SourceKey) -> SkillRepository? {
        repos.first { Self.sourceKey(kind: $0.kind, scope: $0.scope) == key }
    }

    // MARK: project

    func addProject(_ project: Project) async throws {
        try registry?.add(project: project)
        repos.append(contentsOf: Self.makeProjectRepos(for: project))
        await loadAll()
    }

    func removeProject(projectID: UUID) async throws {
        try registry?.remove(projectID: projectID)
        repos.removeAll { repo in
            if case .project(let p) = repo.scope, p.id == projectID { return true }
            return false
        }
        await loadAll()
    }

    // MARK: create / delete

    func createItem(name: String, in sourceKey: SourceKey) async throws -> SkillItem {
        guard let repo = repository(forSourceKey: sourceKey) else {
            throw NSError(domain: "AppStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到目标源"])
        }
        let new = try repo.createSkill(name: name)
        var items = itemsBySource[sourceKey] ?? []
        items.append(new)
        items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        itemsBySource[sourceKey] = items
        selectedSourceKey = sourceKey
        selectedItemID = new.id
        return new
    }

    func deleteItem(_ item: SkillItem) async throws {
        guard let repo = repository(for: item) else {
            throw NSError(domain: "AppStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "找不到源"])
        }
        try repo.deleteItem(item)
        let key = Self.sourceKey(kind: item.kind, scope: item.scope)
        guard var items = itemsBySource[key] else { return }
        items.removeAll { $0.id == item.id }
        itemsBySource[key] = items

        if selectedItemID == item.id {
            selectedItemID = items.first?.id
        }
    }
}
