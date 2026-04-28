import Foundation
import Observation

enum DetailEditorError: Error {
    case noBoundItem
}

@Observable
final class DetailEditorVM {
    private let store: AppStore

    /// The item currently bound to the editor. Nil when no item is selected.
    private(set) var boundItem: SkillItem?

    /// Editor buffer — what the user is currently editing.
    var editingContent: String = ""

    /// True when editingContent differs from the bound item's rawContent.
    var isDirty: Bool {
        guard let item = boundItem else { return false }
        return editingContent != item.rawContent
    }

    init(store: AppStore) {
        self.store = store
    }

    /// Load an item into the editor. Discards any unsaved changes.
    func bind(to item: SkillItem) {
        boundItem = item
        editingContent = item.rawContent
    }

    /// Save current buffer to disk via the owning repository, then update AppStore.
    func save() throws {
        guard let item = boundItem else { throw DetailEditorError.noBoundItem }
        guard let repo = store.repository(for: item) else { throw DetailEditorError.noBoundItem }

        let updated = try repo.save(item: item, content: editingContent)
        boundItem = updated
        editingContent = updated.rawContent
        store.updateItem(updated)
    }
}
