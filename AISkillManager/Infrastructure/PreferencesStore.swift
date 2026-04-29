import Foundation

struct Preferences: Codable {
    var projects: [Project] = []
    var apiKey: String = ""
    var model: String = "gpt-4o"

    init(projects: [Project] = [], apiKey: String = "", model: String = "gpt-4o") {
        self.projects = projects
        self.apiKey   = apiKey
        self.model    = model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
        apiKey   = try container.decodeIfPresent(String.self,    forKey: .apiKey)   ?? ""
        model    = try container.decodeIfPresent(String.self,    forKey: .model)    ?? "gpt-4o"
    }
}

final class PreferencesStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Triskill")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("preferences.json")
    }

    func load() -> Preferences {
        guard let data = try? Data(contentsOf: fileURL),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data) else {
            return Preferences()
        }
        return prefs
    }

    func save(_ prefs: Preferences) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(prefs)
        try data.write(to: fileURL, options: [.atomic])
    }
}
