import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: URL
    var addedAt: Date

    init(id: UUID = UUID(), name: String, path: URL, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.addedAt = addedAt
    }
}
