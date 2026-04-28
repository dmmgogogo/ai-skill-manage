import XCTest
@testable import AISkillManager

final class CursorRulesRepoTests: XCTestCase {
    private var fixtureRoot: URL {
        Bundle(for: type(of: self))
            .url(forResource: "cursor-rules", withExtension: nil)!
    }

    private func makeRepo() -> CursorRulesRepo {
        CursorRulesRepo(scope: .user, root: fixtureRoot)
    }

    func test_listAll_finds_mdc_files() throws {
        let items = try makeRepo().listAll()
        XCTAssertEqual(items.count, 3)
    }

    func test_listAll_uses_filename_when_frontmatter_missing() throws {
        let items = try makeRepo().listAll()
        let item = items.first { $0.mainFileURL.lastPathComponent == "no-frontmatter.mdc" }!
        XCTAssertEqual(item.name, "no-frontmatter")
        XCTAssertEqual(item.description, "")
    }

    func test_listAll_uses_description_from_frontmatter() throws {
        let items = try makeRepo().listAll()
        let item = items.first { $0.mainFileURL.lastPathComponent == "global-ai-behavior.mdc" }!
        XCTAssertEqual(item.description, "Global AI behavior rules")
    }

    func test_listAll_containerURL_is_nil() throws {
        let items = try makeRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.containerURL == nil })
    }

    func test_listAll_hasSubdirectories_is_always_false() throws {
        let items = try makeRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.hasSubdirectories == false })
    }

    func test_listAll_skips_non_mdc_files() throws {
        let extraFile = fixtureRoot.appendingPathComponent("readme.txt")
        try? "x".write(to: extraFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: extraFile) }

        let items = try makeRepo().listAll()
        XCTAssertFalse(items.contains { $0.name == "readme" })
    }

    func test_listAll_returns_empty_for_missing_root() throws {
        let bogus = fixtureRoot.appendingPathComponent("does-not-exist")
        let repo = CursorRulesRepo(scope: .user, root: bogus)
        XCTAssertTrue(try repo.listAll().isEmpty)
    }
}
