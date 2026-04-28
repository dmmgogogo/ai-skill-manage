import Foundation

class DirectorySkillRepoBase: SkillRepository {
    let kind: SourceKind
    let scope: SourceScope
    let root: URL

    init(kind: SourceKind, scope: SourceScope, root: URL) {
        self.kind = kind
        self.scope = scope
        self.root = root
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
                                                   includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                                                   options: [.skipsHiddenFiles])) ?? []

        var items: [SkillItem] = []
        for dir in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            if dir.lastPathComponent.hasPrefix(".") { continue }

            let mainFileURL = dir.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: mainFileURL.path) else { continue }

            guard let item = makeItem(containerURL: dir, mainFileURL: mainFileURL) else { continue }
            items.append(item)
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func makeItem(containerURL: URL, mainFileURL: URL) -> SkillItem? {
        guard let content = try? String(contentsOf: mainFileURL, encoding: .utf8) else { return nil }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: mainFileURL.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size = (attrs[.size] as? Int) ?? 0

        let parsed = YAMLFrontmatter.parseShallow(from: content)
        let dirName = containerURL.lastPathComponent
        let name = parsed.name ?? dirName
        let desc = parsed.description ?? ""

        let hasSubs = detectSubdirectories(in: containerURL)

        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: mainFileURL),
            kind: kind,
            scope: scope,
            mainFileURL: mainFileURL,
            containerURL: containerURL,
            name: name,
            description: desc,
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: hasSubs
        )
    }

    private func detectSubdirectories(in container: URL) -> Bool {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: container,
                                                   includingPropertiesForKeys: [.isDirectoryKey],
                                                   options: [.skipsHiddenFiles])) ?? []
        for entry in entries {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                return true
            }
        }
        return false
    }

    func save(item: SkillItem, content: String) throws -> SkillItem {
        try AtomicWriter.write(content, to: item.mainFileURL)

        let attrs = try FileManager.default.attributesOfItem(atPath: item.mainFileURL.path)
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size = (attrs[.size] as? Int) ?? 0

        let parsed = YAMLFrontmatter.parseShallow(from: content)
        let dirName = item.containerURL?.lastPathComponent ?? item.mainFileURL.deletingPathExtension().lastPathComponent
        let name = parsed.name ?? dirName
        let desc = parsed.description ?? ""

        return SkillItem(
            id: item.id,
            kind: item.kind,
            scope: item.scope,
            mainFileURL: item.mainFileURL,
            containerURL: item.containerURL,
            name: name,
            description: desc,
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: item.hasSubdirectories
        )
    }

    func createSkill(name: String) throws -> SkillItem {
        if let reason = SkillNameValidator.reasonInvalid(name) {
            throw SkillRepositoryError.invalidName(reason: reason)
        }

        let containerURL = root.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: containerURL.path) {
            throw SkillRepositoryError.nameCollision(name: name, existingPath: containerURL)
        }

        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let mainFileURL = containerURL.appendingPathComponent("SKILL.md")
        let template = """
        ---
        name: \(name)
        description: 一句话描述何时调用此 skill
        ---

        # \(name)

        在这里写 skill 内容。
        """
        try template.write(to: mainFileURL, atomically: true, encoding: .utf8)

        let attrs = (try? FileManager.default.attributesOfItem(atPath: mainFileURL.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size = (attrs[.size] as? Int) ?? 0

        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: mainFileURL),
            kind: kind,
            scope: scope,
            mainFileURL: mainFileURL,
            containerURL: containerURL,
            name: name,
            description: "一句话描述何时调用此 skill",
            rawContent: template,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func deleteItem(_ item: SkillItem) throws {
        guard let containerURL = item.containerURL else {
            throw SkillRepositoryError.invalidName(reason: "目录式 skill 必须有 containerURL")
        }
        try FileManager.default.trashItem(at: containerURL, resultingItemURL: nil)
    }
}
