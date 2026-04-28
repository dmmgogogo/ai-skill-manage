import Foundation

final class CursorSkillsRepo: DirectorySkillRepoBase {
    static let userRoot: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cursor/skills")

    init(scope: SourceScope = .user, root: URL? = nil) {
        super.init(kind: .cursorSkills, scope: scope, root: root ?? Self.userRoot)
    }
}
