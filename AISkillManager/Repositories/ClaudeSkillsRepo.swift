import Foundation

final class ClaudeSkillsRepo: DirectorySkillRepoBase {
    static let userRoot: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/skills")

    init(scope: SourceScope = .user, root: URL? = nil) {
        super.init(kind: .claudeSkills, scope: scope, root: root ?? Self.userRoot)
    }
}
