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
        do { try modelContext.save() } catch { AppLogger.store.error("DuaBookmarkStore save failed: \(error)") }
    }

    func setColor(_ color: BookmarkColor?, categoryId: Int, duaId: Int) {
        let key = "\(categoryId):\(duaId)"
        guard let bookmark = fetchAll().first(where: { $0.duaKey == key }) else { return }
        bookmark.bookmarkColor = color
        do { try modelContext.save() } catch { AppLogger.store.error("DuaBookmarkStore save failed: \(error)") }
        NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
    }

    func allBookmarks() -> [DuaBookmark] {
        fetchAll().sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchAll() -> [DuaBookmark] {
        (try? modelContext.fetch(FetchDescriptor<DuaBookmark>())) ?? []
    }
}
