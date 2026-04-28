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
}
