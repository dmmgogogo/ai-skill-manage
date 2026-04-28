import Foundation

struct SkillItem: Identifiable, Hashable {
    let id: SkillItemID
    let kind: SourceKind
    let scope: SourceScope
    let mainFileURL: URL
    let containerURL: URL?
    var name: String
    var description: String
    var rawContent: String
    var fileModifiedAt: Date
    var sizeBytes: Int
    var hasSubdirectories: Bool
}
