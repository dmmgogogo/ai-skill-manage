import Foundation

final class AgentsMdRepo: SkillRepository {
    let kind: SourceKind = .agentsMd
    let scope: SourceScope

    // Ordered list of candidate file URLs. listAll() returns items for all that exist;
    // createSkill() creates at the first candidate URL.
    private let candidateURLs: [URL]

    static func defaultUserCandidates() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("AGENTS.md"),
            home.appendingPathComponent(".codex/README.md"),
        ]
    }

    /// General initializer — tests inject mock paths via `candidates`.
    init(scope: SourceScope = .user, candidates: [URL]? = nil) {
        self.scope = scope
        self.candidateURLs = candidates ?? Self.defaultUserCandidates()
    }

    /// Convenience initializer for project-level repos.
    convenience init(scope: SourceScope, projectRoot: URL) {
        self.init(scope: scope,
                  candidates: [projectRoot.appendingPathComponent("AGENTS.md")])
    }

    // rootExists is always true: candidate files live in fixed locations with no single root dir.
    var rootExists: Bool { true }

    func listAll() throws -> [SkillItem] {
        let fm = FileManager.default
        return candidateURLs.compactMap { url in
            guard fm.fileExists(atPath: url.path) else { return nil }
            return makeItem(fileURL: url)
        }
    }

    private func makeItem(fileURL: URL) -> SkillItem? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let attrs = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size  = (attrs[.size] as? Int) ?? 0
        let name  = fileURL.deletingPathExtension().lastPathComponent
        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: fileURL),
            kind: kind,
            scope: scope,
            mainFileURL: fileURL,
            containerURL: nil,
            name: name,
            description: "",
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func save(item: SkillItem, content: String) throws -> SkillItem {
        try AtomicWriter.write(content, to: item.mainFileURL)
        let attrs = try FileManager.default.attributesOfItem(atPath: item.mainFileURL.path)
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size  = (attrs[.size] as? Int) ?? 0
        return SkillItem(
            id: item.id,
            kind: item.kind,
            scope: item.scope,
            mainFileURL: item.mainFileURL,
            containerURL: nil,
            name: item.name,
            description: item.description,
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func createSkill(name: String) throws -> SkillItem {
        guard let target = candidateURLs.first else {
            throw SkillRepositoryError.invalidName(reason: "无候选文件路径")
        }
        if FileManager.default.fileExists(atPath: target.path) {
            throw SkillRepositoryError.nameCollision(name: target.lastPathComponent,
                                                     existingPath: target)
        }
        let parent = target.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        let template = """
        # \(target.lastPathComponent)

        在这里写项目级 Codex 指导内容。
        """
        try template.write(to: target, atomically: true, encoding: .utf8)

        let attrs = (try? FileManager.default.attributesOfItem(atPath: target.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size  = (attrs[.size] as? Int) ?? 0
        let itemName = target.deletingPathExtension().lastPathComponent

        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: target),
            kind: kind,
            scope: scope,
            mainFileURL: target,
            containerURL: nil,
            name: itemName,
            description: "",
            rawContent: template,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func deleteItem(_ item: SkillItem) throws {
        try FileManager.default.trashItem(at: item.mainFileURL, resultingItemURL: nil)
    }
}
