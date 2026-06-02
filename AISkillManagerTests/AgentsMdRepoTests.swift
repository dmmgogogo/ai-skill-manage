import XCTest
@testable import AISkillManager

final class AgentsMdRepoTests: XCTestCase {

    // MARK: - Helpers

    private var fixtureBase: URL {
        Bundle(for: type(of: self))
            .url(forResource: "agents-md", withExtension: nil)!
    }

    private var agentsMdURL: URL {
        fixtureBase.appendingPathComponent("AGENTS.md")
    }

    private var codexReadmeURL: URL {
        fixtureBase.appendingPathComponent("codex-readme/README.md")
    }

    private func makeUserRepo(candidates: [URL]? = nil) -> AgentsMdRepo {
        AgentsMdRepo(scope: .user, candidates: candidates ?? [agentsMdURL, codexReadmeURL])
    }

    private func makeProjectRepo(projectRoot: URL) -> AgentsMdRepo {
        AgentsMdRepo(scope: .project(Project(name: "test", path: projectRoot)),
                     candidates: [projectRoot.appendingPathComponent("AGENTS.md")])
    }

    // MARK: - listAll

    func test_listAll_finds_both_candidates_when_both_exist() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertEqual(items.count, 2)
    }

    func test_listAll_skips_missing_candidate() throws {
        let bogus = fixtureBase.appendingPathComponent("does-not-exist.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL, bogus])
        let items = try repo.listAll()
        XCTAssertEqual(items.count, 1)
    }

    func test_listAll_returns_empty_when_no_candidates_exist() throws {
        let bogus1 = fixtureBase.appendingPathComponent("no1.md")
        let bogus2 = fixtureBase.appendingPathComponent("no2.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [bogus1, bogus2])
        let items = try repo.listAll()
        XCTAssertTrue(items.isEmpty)
    }

    func test_listAll_name_is_filename_without_extension() throws {
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL])
        let items = try repo.listAll()
        XCTAssertEqual(items.first?.name, "AGENTS")
    }

    func test_listAll_containerURL_is_nil() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.containerURL == nil })
    }

    func test_listAll_hasSubdirectories_is_false() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.hasSubdirectories == false })
    }

    func test_listAll_rawContent_is_not_empty() throws {
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL])
        let items = try repo.listAll()
        XCTAssertFalse(items.first?.rawContent.isEmpty ?? true)
    }

    func test_listAll_kind_is_agentsMd() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.kind == .agentsMd })
    }

    // MARK: - rootExists

    func test_rootExists_always_true() {
        XCTAssertTrue(makeUserRepo().rootExists)
    }

    // MARK: - createSkill

    func test_createSkill_creates_agents_md_when_not_present() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsMd-create-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let target = tmp.appendingPathComponent("AGENTS.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [target])
        let item = try repo.createSkill(name: "ignored")

        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertEqual(item.kind, .agentsMd)
        XCTAssertFalse(item.rawContent.isEmpty)
    }

    func test_createSkill_throws_nameCollision_when_file_exists() throws {
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL])
        XCTAssertThrowsError(try repo.createSkill(name: "anything")) { error in
            guard case SkillRepositoryError.nameCollision = error else {
                XCTFail("Expected nameCollision, got \(error)")
                return
            }
        }
    }

    // MARK: - save

    func test_save_writes_new_content() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsMd-save-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let target = tmp.appendingPathComponent("AGENTS.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [target])
        let created = try repo.createSkill(name: "x")

        let updated = try repo.save(item: created, content: "# Updated\n\nNew content.")
        XCTAssertEqual(updated.rawContent, "# Updated\n\nNew content.")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "# Updated\n\nNew content.")
    }

    // MARK: - deleteItem

    func test_deleteItem_removes_file() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsMd-delete-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let target = tmp.appendingPathComponent("AGENTS.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [target])
        let item = try repo.createSkill(name: "x")

        try repo.deleteItem(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
}
