import XCTest
@testable import AISkillManager

@MainActor
final class AppStoreTests: XCTestCase {
    private func makeStubStore() -> AppStore {
        let dirRoot = Bundle(for: type(of: self))
            .url(forResource: "dir-source", withExtension: nil)!
        let mdcRoot = Bundle(for: type(of: self))
            .url(forResource: "cursor-rules", withExtension: nil)!

        let repos: [SkillRepository] = [
            DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: dirRoot),
            DirectorySkillRepoBase(kind: .codexSkills,  scope: .user, root: dirRoot),
            DirectorySkillRepoBase(kind: .cursorSkills, scope: .user, root: dirRoot),
            CursorRulesRepo(scope: .user, root: mdcRoot),
        ]
        return AppStore(repos: repos)
    }

    func test_initial_state_is_empty() {
        let store = makeStubStore()
        XCTAssertTrue(store.itemsBySource.isEmpty)
        XCTAssertNil(store.selectedSourceKey)
        XCTAssertNil(store.selectedItemID)
    }

    @MainActor
    func test_loadAll_populates_items_grouped_by_source() async {
        let store = makeStubStore()
        await store.loadAll()
        XCTAssertEqual(store.itemsBySource.count, 4)

        let claudeKey = AppStore.sourceKey(kind: .claudeSkills, scope: .user)
        XCTAssertEqual(store.itemsBySource[claudeKey]?.count, 4)
    }

    @MainActor
    func test_loadAll_auto_selects_first_nonempty_source() async {
        let store = makeStubStore()
        await store.loadAll()
        XCTAssertNotNil(store.selectedSourceKey)
        XCTAssertNotNil(store.selectedItemID)
    }

    @MainActor
    func test_select_source_changes_selectedSourceKey() async {
        let store = makeStubStore()
        await store.loadAll()
        let codexKey = AppStore.sourceKey(kind: .codexSkills, scope: .user)
        store.selectSource(codexKey)
        XCTAssertEqual(store.selectedSourceKey, codexKey)
    }

    @MainActor
    func test_select_source_auto_selects_first_item_in_that_source() async {
        let store = makeStubStore()
        await store.loadAll()
        let codexKey = AppStore.sourceKey(kind: .codexSkills, scope: .user)
        store.selectSource(codexKey)
        XCTAssertNotNil(store.selectedItemID)
        XCTAssertEqual(store.currentItem?.kind, .codexSkills)
    }

    @MainActor
    func test_currentItem_returns_selected() async {
        let store = makeStubStore()
        await store.loadAll()
        let claudeKey = AppStore.sourceKey(kind: .claudeSkills, scope: .user)
        store.selectSource(claudeKey)
        let firstItem = store.itemsBySource[claudeKey]!.first!
        store.selectedItemID = firstItem.id
        XCTAssertEqual(store.currentItem?.id, firstItem.id)
    }

    @MainActor
    func test_currentItem_nil_when_id_not_found() async {
        let store = makeStubStore()
        await store.loadAll()
        store.selectedItemID = SkillItemID(kind: .claudeSkills, scopeKey: "user", pathFingerprint: "deadbeef0000")
        XCTAssertNil(store.currentItem)
    }

    @MainActor
    func test_updateItem_replaces_item_in_memory() async {
        let store = makeStubStore()
        await store.loadAll()
        let claudeKey = AppStore.sourceKey(kind: .claudeSkills, scope: .user)
        let original = store.itemsBySource[claudeKey]!.first!

        var modified = original
        modified.name = "renamed-in-memory"
        store.updateItem(modified)

        XCTAssertEqual(store.itemsBySource[claudeKey]?.first?.name, "renamed-in-memory")
    }

    @MainActor
    func test_repository_for_item_returns_matching_repo() async {
        let store = makeStubStore()
        await store.loadAll()
        let claudeKey = AppStore.sourceKey(kind: .claudeSkills, scope: .user)
        let item = store.itemsBySource[claudeKey]!.first!

        let repo = store.repository(for: item)
        XCTAssertNotNil(repo)
        XCTAssertEqual(repo?.kind, .claudeSkills)
    }

    private func makeStoreWithRegistry() -> (AppStore, URL) {
        let dirRoot = Bundle(for: type(of: self))
            .url(forResource: "dir-source", withExtension: nil)!
        let mdcRoot = Bundle(for: type(of: self))
            .url(forResource: "cursor-rules", withExtension: nil)!
        let prefsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("appstore-\(UUID().uuidString).json")
        let registry = ProjectRegistry(store: PreferencesStore(fileURL: prefsURL))

        let repos: [SkillRepository] = [
            DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: dirRoot),
            DirectorySkillRepoBase(kind: .codexSkills,  scope: .user, root: dirRoot),
            DirectorySkillRepoBase(kind: .cursorSkills, scope: .user, root: dirRoot),
            CursorRulesRepo(scope: .user, root: mdcRoot),
        ]
        let store = AppStore(repos: repos, registry: registry)
        return (store, prefsURL)
    }

    @MainActor
    func test_addProject_appends_4_repos() async throws {
        let (store, prefsURL) = makeStoreWithRegistry()
        defer { try? FileManager.default.removeItem(at: prefsURL) }
        await store.loadAll()
        XCTAssertEqual(store.repos.count, 4)

        let projectDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appstore-proj-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectDir) }

        let project = Project(name: "demo", path: projectDir)
        try await store.addProject(project)

        XCTAssertEqual(store.repos.count, 8)
    }

    @MainActor
    func test_removeProject_removes_repos() async throws {
        let (store, prefsURL) = makeStoreWithRegistry()
        defer { try? FileManager.default.removeItem(at: prefsURL) }
        let projectDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appstore-proj-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectDir) }

        let project = Project(name: "demo", path: projectDir)
        try await store.addProject(project)
        XCTAssertEqual(store.repos.count, 8)

        try await store.removeProject(projectID: project.id)
        XCTAssertEqual(store.repos.count, 4)
    }

    @MainActor
    func test_createItem_inserts_into_source_and_selects() async throws {
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("createItem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let store = AppStore(repos: [
            DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: tmpRoot)
        ])
        await store.loadAll()
        let claudeKey = AppStore.sourceKey(kind: .claudeSkills, scope: .user)

        let new = try await store.createItem(name: "fresh", in: claudeKey)

        XCTAssertEqual(store.itemsBySource[claudeKey]?.count, 1)
        XCTAssertEqual(store.selectedSourceKey, claudeKey)
        XCTAssertEqual(store.selectedItemID, new.id)
    }

    @MainActor
    func test_deleteItem_removes_from_source_and_advances_selection() async throws {
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("deleteItem-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let store = AppStore(repos: [
            DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: tmpRoot)
        ])
        let claudeKey = AppStore.sourceKey(kind: .claudeSkills, scope: .user)

        let a = try await store.createItem(name: "a", in: claudeKey)
        _ = try await store.createItem(name: "b", in: claudeKey)
        XCTAssertEqual(store.itemsBySource[claudeKey]?.count, 2)

        try await store.deleteItem(a)
        XCTAssertEqual(store.itemsBySource[claudeKey]?.count, 1)
    }
}
