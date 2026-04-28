import Foundation

enum SourceScope: Equatable, Hashable {
    case user
    case project(Project)

    var key: String {
        switch self {
        case .user: return "user"
        case .project(let p): return "project:\(p.id.uuidString)"
        }
    }

    var displayLabel: String {
        switch self {
        case .user: return "用户级"
        case .project(let p): return "项目: \(p.name)"
        }
    }
}
