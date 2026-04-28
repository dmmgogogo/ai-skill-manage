import XCTest
@testable import AISkillManager

final class DirectorySkillRepoBaseTests: XCTestCase {
    private var fixtureRoot: URL {
        Bundle(for: type(of: self))
            .url(forResource: "dir-source", withExtension: nil)!
    }

    private func makeRepo() -> DirectorySkillRepoBase {
        DirectorySkillRepoBase(
            kind: .claudeSkills,
            scope: .user,
            root: fixtureRoot
        )
    }

    func test_rootExists_true_when_directory_present() {
        XCTAssertTrue(makeRepo().rootExists)
    }

    func test_rootExists_false_when_directory_missing() {
        let bogus = fixtureRoot.appendingPathComponent("does-not-exist")
        let repo = DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: bogus)
        XCTAssertFalse(repo.rootExists)
    }

    func test_listAll_returns_all_skills() throws {
        let items = try makeRepo().listAll()
        let names = Set(items.map(\.name))
        XCTAssertEqual(names, ["skill-good", "skill-no-desc", "skill-bad-yaml", "skill-with-subs"])
    }

    func test_listAll_extracts_name_and_description() throws {
        let items = try makeRepo().listAll()
        let good = items.first { $0.name == "skill-good" }!
        XCTAssertEqual(good.description, "Good skill with both fields")
    }

    func test_listAll_uses_directory_name_when_frontmatter_name_missing() throws {
        let items = try makeRepo().listAll()
        let bad = items.first { $0.mainFileURL.path.contains("skill-bad-yaml") }!
        XCTAssertEqual(bad.name, "skill-bad-yaml")
        XCTAssertEqual(bad.description, "")
    }

    func test_listAll_detects_subdirectories() throws {
        let items = try makeRepo().listAll()
        let withSubs = items.first { $0.name == "skill-with-subs" }!
        XCTAssertTrue(withSubs.hasSubdirectories)

        let good = items.first { $0.name == "skill-good" }!
        XCTAssertFalse(good.hasSubdirectories)
    }

    func test_listAll_includes_raw_content() throws {
        let items = try makeRepo().listAll()
        let good = items.first { $0.name == "skill-good" }!
        XCTAssertTrue(good.rawContent.contains("Body content here."))
        XCTAssertTrue(good.rawContent.hasPrefix("---"))
    }

    func test_listAll_skips_files_at_root() throws {
        let extraFile = fixtureRoot.appendingPathComponent("loose-file.md")
        try? "loose".write(to: extraFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: extraFile) }

        let items = try makeRepo().listAll()
        XCTAssertFalse(items.contains { $0.name == "loose-file" })
    }

    func test_listAll_skips_dotfiles() throws {
        let dsStore = fixtureRoot.appendingPathComponent(".DS_Store")
        try? "x".write(to: dsStore, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dsStore) }

        let items = try makeRepo().listAll()
        XCTAssertFalse(items.contains { $0.name.hasPrefix(".") })
    }

    func test_listAll_returns_empty_for_missing_root() throws {
        let bogus = fixtureRoot.appendingPathComponent("does-not-exist")
        let repo = DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: bogus)
        let items = try repo.listAll()
        XCTAssertTrue(items.isEmpty)
    }
}
