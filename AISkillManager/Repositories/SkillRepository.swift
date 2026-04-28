import Foundation

protocol SkillRepository {
    /// The source kind this repository represents.
    var kind: SourceKind { get }

    /// The scope (user-level or project-level) this repository operates in.
    var scope: SourceScope { get }

    /// Whether the underlying root directory currently exists.
    var rootExists: Bool { get }

    /// List all skill items under this repository's root.
    /// Returns an empty array (does not throw) when the root doesn't exist.
    func listAll() throws -> [SkillItem]

    /// Atomically save new content to the item's main file.
    /// Returns the updated SkillItem with refreshed mtime/size and rawContent.
    /// Throws if the file disappeared, was permission-denied, disk full, etc.
    func save(item: SkillItem, content: String) throws -> SkillItem

    /// Create a new skill with the given name. Returns the freshly created SkillItem.
    /// - Throws: SkillRepositoryError.nameCollision if a same-named item already exists,
    ///           .invalidName if name fails validation,
    ///           any FileManager error if root creation/file write fails.
    func createSkill(name: String) throws -> SkillItem

    /// Move the item's underlying file/directory to macOS Trash (recoverable).
    /// - Throws: any FileManager error if trash fails.
    func deleteItem(_ item: SkillItem) throws
}

enum SkillRepositoryError: Error, LocalizedError {
    case nameCollision(name: String, existingPath: URL)
    case invalidName(reason: String)
    case rootDoesNotExist(URL)

    var errorDescription: String? {
        switch self {
        case .nameCollision(let name, let path):
            return "已存在同名条目「\(name)」：\(path.path(percentEncoded: false))"
        case .invalidName(let reason):
            return "名称不合法：\(reason)"
        case .rootDoesNotExist(let url):
            return "目录不存在：\(url.path(percentEncoded: false))"
        }
    }
}

enum SkillNameValidator {
    /// Returns nil if name is valid, otherwise a reason string.
    static func reasonInvalid(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "名称不能为空" }
        if trimmed.contains("/") { return "名称不能包含 /" }
        if trimmed.hasPrefix(".") { return "名称不能以点开头" }
        return nil
    }
}
