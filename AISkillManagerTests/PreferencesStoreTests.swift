import XCTest
@testable import AISkillManager

final class PreferencesStoreTests: XCTestCase {
    private var tmpFile: URL!

    override func setUpWithError() throws {
        tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("prefs-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpFile)
    }

    func test_load_returns_default_when_file_absent() {
        let store = PreferencesStore(fileURL: tmpFile)
        let prefs = store.load()
        XCTAssertTrue(prefs.projects.isEmpty)
    }

    func test_save_then_load_round_trip() throws {
        let store = PreferencesStore(fileURL: tmpFile)
        let project = Project(name: "demo", path: URL(fileURLWithPath: "/tmp/demo"))
        var prefs = Preferences()
        prefs.projects = [project]
        try store.save(prefs)

        let loaded = store.load()
        XCTAssertEqual(loaded.projects.count, 1)
        XCTAssertEqual(loaded.projects.first?.name, "demo")
    }

    func test_load_returns_default_on_corrupt_file() throws {
        try "not valid json".write(to: tmpFile, atomically: true, encoding: .utf8)
        let store = PreferencesStore(fileURL: tmpFile)
        let prefs = store.load()
        XCTAssertTrue(prefs.projects.isEmpty)
    }
}
