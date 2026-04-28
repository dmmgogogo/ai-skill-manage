import Foundation
import Observation

enum ProjectRegistryError: Error, LocalizedError {
    case duplicatePath(URL)

    var errorDescription: String? {
        switch self {
        case .duplicatePath(let url):
            return "已添加过同路径的项目：\(url.path(percentEncoded: false))"
        }
    }
}

@Observable
@MainActor
final class ProjectRegistry {
    private let store: PreferencesStore
    private(set) var projects: [Project]

    init(store: PreferencesStore) {
        self.store = store
        self.projects = store.load().projects
    }

    static func makeDefault() -> ProjectRegistry {
        ProjectRegistry(store: PreferencesStore(fileURL: PreferencesStore.defaultURL()))
    }

    func add(project: Project) throws {
        let normalized = project.path.standardizedFileURL.path
        if projects.contains(where: { $0.path.standardizedFileURL.path == normalized }) {
            throw ProjectRegistryError.duplicatePath(project.path)
        }
        projects.append(project)
        try persist()
    }

    func remove(projectID: UUID) throws {
        projects.removeAll { $0.id == projectID }
        try persist()
    }

    private func persist() throws {
        var prefs = store.load()
        prefs.projects = projects
        try store.save(prefs)
    }
}
