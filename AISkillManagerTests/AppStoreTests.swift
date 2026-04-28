import XCTest
@testable import AISkillManager

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
}
