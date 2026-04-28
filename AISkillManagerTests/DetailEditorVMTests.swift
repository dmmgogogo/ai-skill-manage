import XCTest
@testable import AISkillManager

@MainActor
final class DetailEditorVMTests: XCTestCase {
    private var tmpRoot: URL!
    private var store: AppStore!

    override func setUp() async throws {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DetailEditorVMTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)

        let dir = tmpRoot.appendingPathComponent("alpha")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "---\nname: alpha\n---\noriginal".write(
            to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        store = AppStore(repos: [
            DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: tmpRoot)
        ])
        await store.loadAll()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    func test_initial_state_loads_item_content() {
        let item = store.currentItem!
        let vm = DetailEditorVM(store: store)
        vm.bind(to: item)

        XCTAssertEqual(vm.editingContent, item.rawContent)
        XCTAssertFalse(vm.isDirty)
    }

    func test_editingContent_change_marks_dirty() {
        let item = store.currentItem!
        let vm = DetailEditorVM(store: store)
        vm.bind(to: item)

        vm.editingContent = item.rawContent + "\nnew line"
        XCTAssertTrue(vm.isDirty)
    }

    func test_setting_same_content_keeps_clean() {
        let item = store.currentItem!
        let vm = DetailEditorVM(store: store)
        vm.bind(to: item)

        vm.editingContent = item.rawContent
        XCTAssertFalse(vm.isDirty)
    }

    func test_bind_to_different_item_resets_dirty() {
        let item = store.currentItem!
        let vm = DetailEditorVM(store: store)
        vm.bind(to: item)
        vm.editingContent = "modified"
        XCTAssertTrue(vm.isDirty)

        vm.bind(to: item)
        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.editingContent, item.rawContent)
    }

    func test_save_writes_to_disk_and_clears_dirty() throws {
        let item = store.currentItem!
        let vm = DetailEditorVM(store: store)
        vm.bind(to: item)

        let newContent = "---\nname: alpha\ndescription: edited\n---\n\nedited body"
        vm.editingContent = newContent
        XCTAssertTrue(vm.isDirty)

        try vm.save()

        XCTAssertFalse(vm.isDirty)
        let onDisk = try String(contentsOf: item.mainFileURL, encoding: .utf8)
        XCTAssertEqual(onDisk, newContent)
    }

    func test_save_updates_appstore_item() throws {
        let item = store.currentItem!
        let vm = DetailEditorVM(store: store)
        vm.bind(to: item)

        vm.editingContent = "---\nname: alpha\ndescription: from save\n---\nbody"
        try vm.save()

        let updatedFromStore = store.currentItem!
        XCTAssertEqual(updatedFromStore.description, "from save")
    }

    func test_save_with_no_bound_item_throws() {
        let vm = DetailEditorVM(store: store)
        XCTAssertThrowsError(try vm.save())
    }
}
