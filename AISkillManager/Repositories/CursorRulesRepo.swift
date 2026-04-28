import Foundation

final class CursorRulesRepo: SkillRepository {
    let kind: SourceKind = .cursorRules
    let scope: SourceScope
    let root: URL

    static let userRoot: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cursor/rules")

    init(scope: SourceScope = .user, root: URL? = nil) {
        self.scope = scope
        self.root = root ?? Self.userRoot
    }

    var rootExists: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    func listAll() throws -> [SkillItem] {
        guard rootExists else { return [] }

        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: root,
                                                   includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                   options: [.skipsHiddenFiles])) ?? []

        var items: [SkillItem] = []
        for fileURL in entries {
            guard fileURL.pathExtension == "mdc" else { continue }
            guard let item = makeItem(fileURL: fileURL) else { continue }
            items.append(item)
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func makeItem(fileURL: URL) -> SkillItem? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size = (attrs[.size] as? Int) ?? 0

        let parsed = YAMLFrontmatter.parseShallow(from: content)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let name = parsed.name ?? baseName
        let desc = parsed.description ?? ""

        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: fileURL),
            kind: kind,
            scope: scope,
            mainFileURL: fileURL,
            containerURL: nil,
            name: name,
            description: desc,
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }
}
