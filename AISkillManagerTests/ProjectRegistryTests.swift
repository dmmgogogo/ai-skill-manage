import XCTest
@testable import AISkillManager

@MainActor
final class ProjectRegistryTests: XCTestCase {
    private var tmpFile: URL!

    override func setUp() {
        tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("registry-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpFile)
    }

    private func makeRegistry() -> ProjectRegistry {
        ProjectRegistry(store: PreferencesStore(fileURL: tmpFile))
    }

    func test_initial_is_empty() {
        XCTAssertTrue(makeRegistry().projects.isEmpty)
    }

    func test_add_persists() throws {
        let r1 = makeRegistry()
        try r1.add(project: Project(name: "A", path: URL(fileURLWithPath: "/tmp/A")))
        try r1.add(project: Project(name: "B", path: URL(fileURLWithPath: "/tmp/B")))

        let r2 = makeRegistry()
        XCTAssertEqual(r2.projects.map(\.name), ["A", "B"])
    }

    func test_remove() throws {
        let r = makeRegistry()
        let p = Project(name: "kill", path: URL(fileURLWithPath: "/tmp/kill"))
        try r.add(project: p)
        XCTAssertEqual(r.projects.count, 1)

        try r.remove(projectID: p.id)
        XCTAssertTrue(r.projects.isEmpty)
    }

    func test_add_duplicate_path_throws() throws {
        let r = makeRegistry()
        let path = URL(fileURLWithPath: "/tmp/same")
        try r.add(project: Project(name: "first", path: path))
        XCTAssertThrowsError(try r.add(project: Project(name: "second", path: path)))
    }
}
