import Foundation

final class CodexSkillsRepo: DirectorySkillRepoBase {
    static let userRoot: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/skills")

    init(scope: SourceScope = .user, root: URL? = nil) {
        super.init(kind: .codexSkills, scope: scope, root: root ?? Self.userRoot)
    }
}
