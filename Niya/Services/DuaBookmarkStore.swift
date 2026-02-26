import Foundation
import SwiftData

@MainActor
final class DuaBookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isBookmarked(categoryId: Int, duaId: Int) -> Bool {
        let key = "\(categoryId):\(duaId)"
        return fetchAll().contains { $0.duaKey == key }
    }

    func toggle(categoryId: Int, duaId: Int) {
        let key = "\(categoryId):\(duaId)"
        if let existing = fetchAll().first(where: { $0.duaKey == key }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(DuaBookmark(categoryId: categoryId, duaId: duaId))
        }
        try? modelContext.save()
    }

    func allBookmarks() -> [DuaBookmark] {
        fetchAll().sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchAll() -> [DuaBookmark] {
        (try? modelContext.fetch(FetchDescriptor<DuaBookmark>())) ?? []
    }
}
