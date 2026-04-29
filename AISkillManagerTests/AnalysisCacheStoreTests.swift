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
