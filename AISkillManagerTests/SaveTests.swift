import XCTest
@testable import AISkillManager

final class SaveTests: XCTestCase {
    private var tmpRoot: URL!

    override func setUpWithError() throws {
        tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AISkillManagerSaveTests-\(UUID().uuidString)")
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

    private func seedDirectorySkill(name: String, content: String) throws -> URL {
        let skillDir = tmpRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let mainFile = skillDir.appendingPathComponent("SKILL.md")
        try content.write(to: mainFile, atomically: true, encoding: .utf8)
        return mainFile
    }

    private func seedRule(name: String, content: String) throws -> URL {
        let fileURL = tmpRoot.appendingPathComponent("\(name).mdc")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: DirectorySkillRepoBase save

    func test_directory_save_writes_new_content() throws {
        _ = try seedDirectorySkill(name: "alpha", content: "---\nname: alpha\n---\n\nold body")
        let repo = makeDirectoryRepo()
        let original = try repo.listAll().first { $0.name == "alpha" }!

        let newContent = "---\nname: alpha\ndescription: updated\n---\n\nnew body"
        let updated = try repo.save(item: original, content: newContent)

        XCTAssertEqual(updated.rawContent, newContent)
        let onDisk = try String(contentsOf: updated.mainFileURL, encoding: .utf8)
        XCTAssertEqual(onDisk, newContent)
    }

    func test_directory_save_returns_updated_mtime_and_size() throws {
        _ = try seedDirectorySkill(name: "beta", content: "x")
        let repo = makeDirectoryRepo()
        let original = try repo.listAll().first { $0.name == "beta" }!
        Thread.sleep(forTimeInterval: 0.01)

        let updated = try repo.save(item: original, content: "much longer content than x")
        XCTAssertGreaterThan(updated.sizeBytes, original.sizeBytes)
        XCTAssertGreaterThanOrEqual(updated.fileModifiedAt, original.fileModifiedAt)
    }

    func test_directory_save_throws_when_file_was_deleted() throws {
        _ = try seedDirectorySkill(name: "ghost", content: "x")
        let repo = makeDirectoryRepo()
        let original = try repo.listAll().first { $0.name == "ghost" }!

        try FileManager.default.removeItem(at: original.containerURL!)

        XCTAssertThrowsError(try repo.save(item: original, content: "anything")) { error in
            XCTAssertNotNil(error)
        }
    }

    func test_directory_save_does_not_leave_temp_files() throws {
        _ = try seedDirectorySkill(name: "clean", content: "x")
        let repo = makeDirectoryRepo()
        let original = try repo.listAll().first { $0.name == "clean" }!

        _ = try repo.save(item: original, content: "y")

        let entries = try FileManager.default.contentsOfDirectory(at: original.containerURL!,
                                                                  includingPropertiesForKeys: nil)
        let tmpFiles = entries.filter { $0.lastPathComponent.contains(".tmp.") }
        XCTAssertTrue(tmpFiles.isEmpty, "Temp files should be cleaned up after save")
    }

    // MARK: CursorRulesRepo save

    func test_rules_save_writes_new_content() throws {
        _ = try seedRule(name: "rule-a", content: "---\nalwaysApply: true\n---\nold")
        let repo = makeRulesRepo()
        let original = try repo.listAll().first { $0.mainFileURL.lastPathComponent == "rule-a.mdc" }!

        let newContent = "---\nalwaysApply: false\n---\nnew"
        let updated = try repo.save(item: original, content: newContent)

        XCTAssertEqual(updated.rawContent, newContent)
        XCTAssertEqual(try String(contentsOf: updated.mainFileURL, encoding: .utf8), newContent)
    }

    func test_rules_save_throws_when_file_was_deleted() throws {
        _ = try seedRule(name: "rule-ghost", content: "x")
        let repo = makeRulesRepo()
        let original = try repo.listAll().first { $0.mainFileURL.lastPathComponent == "rule-ghost.mdc" }!

        try FileManager.default.removeItem(at: original.mainFileURL)

        XCTAssertThrowsError(try repo.save(item: original, content: "anything"))
    }
}
