import XCTest
@testable import AISkillManager

final class CreateDeleteTests: XCTestCase {
    private var tmpRoot: URL!

    override func setUpWithError() throws {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreateDeleteTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    private func makeDirectoryRepo() -> DirectorySkillRepoBase {
        DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: tmpRoot)
    }

    private func makeRulesRepo() -> CursorRulesRepo {
        CursorRulesRepo(scope: .user, root: tmpRoot)
    }

    // MARK: directory create

    func test_directory_create_makes_dir_and_skill_md() throws {
        let repo = makeDirectoryRepo()
        let item = try repo.createSkill(name: "alpha")

        XCTAssertEqual(item.name, "alpha")
        XCTAssertEqual(item.containerURL?.lastPathComponent, "alpha")
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.mainFileURL.path))

        let content = try String(contentsOf: item.mainFileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("name: alpha"))
        XCTAssertTrue(content.contains("---"))
    }

    func test_directory_create_creates_root_if_missing() throws {
        let nested = tmpRoot.appendingPathComponent("brand-new-root")
        let repo = DirectorySkillRepoBase(kind: .claudeSkills, scope: .user, root: nested)

        XCTAssertFalse(FileManager.default.fileExists(atPath: nested.path))
        let item = try repo.createSkill(name: "first")
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.mainFileURL.path))
    }

    func test_directory_create_throws_on_name_collision() throws {
        let repo = makeDirectoryRepo()
        _ = try repo.createSkill(name: "dup")
        XCTAssertThrowsError(try repo.createSkill(name: "dup")) { error in
            guard case SkillRepositoryError.nameCollision = error else {
                return XCTFail("Expected nameCollision, got \(error)")
            }
        }
    }

    func test_directory_create_throws_on_invalid_name() throws {
        let repo = makeDirectoryRepo()
        XCTAssertThrowsError(try repo.createSkill(name: ""))
        XCTAssertThrowsError(try repo.createSkill(name: "has/slash"))
        XCTAssertThrowsError(try repo.createSkill(name: ".hidden"))
    }

    // MARK: directory delete

    func test_directory_delete_moves_to_trash() throws {
        let repo = makeDirectoryRepo()
        let item = try repo.createSkill(name: "doomed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.containerURL!.path))

        try repo.deleteItem(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.containerURL!.path))
    }

    func test_directory_delete_throws_when_item_already_gone() throws {
        let repo = makeDirectoryRepo()
        let item = try repo.createSkill(name: "vanish")
        try FileManager.default.removeItem(at: item.containerURL!)
        XCTAssertThrowsError(try repo.deleteItem(item))
    }

    // MARK: rules create

    func test_rules_create_makes_mdc_file() throws {
        let repo = makeRulesRepo()
        let item = try repo.createSkill(name: "rule-1")

        XCTAssertEqual(item.name, "rule-1")
        XCTAssertEqual(item.mainFileURL.lastPathComponent, "rule-1.mdc")
        XCTAssertNil(item.containerURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.mainFileURL.path))

        let content = try String(contentsOf: item.mainFileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("alwaysApply: false"))
    }

    func test_rules_create_creates_root_if_missing() throws {
        let nested = tmpRoot.appendingPathComponent("rules-fresh")
        let repo = CursorRulesRepo(scope: .user, root: nested)
        XCTAssertFalse(FileManager.default.fileExists(atPath: nested.path))
        _ = try repo.createSkill(name: "r1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.appendingPathComponent("r1.mdc").path))
    }

    func test_rules_create_throws_on_collision() throws {
        let repo = makeRulesRepo()
        _ = try repo.createSkill(name: "rdup")
        XCTAssertThrowsError(try repo.createSkill(name: "rdup")) { error in
            guard case SkillRepositoryError.nameCollision = error else {
                return XCTFail("Expected nameCollision, got \(error)")
            }
        }
    }

    func test_rules_create_throws_on_invalid_name() throws {
        let repo = makeRulesRepo()
        XCTAssertThrowsError(try repo.createSkill(name: ""))
        XCTAssertThrowsError(try repo.createSkill(name: "has/slash"))
        XCTAssertThrowsError(try repo.createSkill(name: ".hidden"))
    }

    // MARK: rules delete

    func test_rules_delete_moves_to_trash() throws {
        let repo = makeRulesRepo()
        let item = try repo.createSkill(name: "to-delete")
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.mainFileURL.path))

        try repo.deleteItem(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.mainFileURL.path))
    }
}
