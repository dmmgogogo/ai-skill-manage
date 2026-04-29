import Foundation

struct AnalysisEntry: Codable {
    var result: String
    var analyzedAt: Date
}

final class AnalysisCacheStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func defaultURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Triskill")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analysis-cache.json")
    }

    func entry(for path: String) -> AnalysisEntry? {
        loadAll()[path]
    }

    func save(entry: AnalysisEntry, for path: String) throws {
        var cache = loadAll()
        cache[path] = entry
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cache)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func loadAll() -> [String: AnalysisEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? decoder.decode([String: AnalysisEntry].self, from: data) else {
            return [:]
        }
        return cache
    }
}
