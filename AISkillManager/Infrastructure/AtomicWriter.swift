import Foundation

enum AtomicWriter {
    /// Atomically writes content to `target` via a sibling tmp file + replaceItemAt.
    /// Throws on any write/replace failure. Cleans up tmp file on failure.
    static func write(_ content: String, to target: URL) throws {
        let parent = target.deletingLastPathComponent()
        let tmpName = ".\(target.lastPathComponent).tmp.\(UUID().uuidString)"
        let tmpURL = parent.appendingPathComponent(tmpName)

        let data = Data(content.utf8)

        do {
            try data.write(to: tmpURL, options: [.atomic])
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            throw error
        }

        do {
            guard FileManager.default.fileExists(atPath: target.path) else {
                try? FileManager.default.removeItem(at: tmpURL)
                throw CocoaError(.fileNoSuchFile)
            }
            _ = try FileManager.default.replaceItemAt(target, withItemAt: tmpURL)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            throw error
        }
    }
}
