import Foundation
import SwiftData

@MainActor
final class DuaBookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isBookmarked(categoryId: Int, duaId: Int) -> Bool {
        fetchByKey(categoryId: categoryId, duaId: duaId) != nil
    }

    func toggle(categoryId: Int, duaId: Int) {
        if let existing = fetchByKey(categoryId: categoryId, duaId: duaId) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(DuaBookmark(categoryId: categoryId, duaId: duaId))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("DuaBookmarkStore save failed: \(error)") }
    }

    func setColor(_ color: BookmarkColor?, categoryId: Int, duaId: Int) {
        guard let bookmark = fetchByKey(categoryId: categoryId, duaId: duaId) else { return }
        bookmark.bookmarkColor = color
        do { try modelContext.save() } catch { AppLogger.store.error("DuaBookmarkStore save failed: \(error)") }
        NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
    }

    func allBookmarks() -> [DuaBookmark] {
        let all = fetchAll().sorted { $0.createdAt < $1.createdAt }
        var seen = Set<String>()
        var result: [DuaBookmark] = []
        var toDelete: [DuaBookmark] = []
        for item in all {
            if seen.insert(item.duaKey).inserted {
                result.append(item)
            } else {
                toDelete.append(item)
            }
        }
        if !toDelete.isEmpty {
            for dupe in toDelete { modelContext.delete(dupe) }
            do { try modelContext.save() } catch { AppLogger.store.error("DuaBookmarkStore dedup save: \(error)") }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchByKey(categoryId: Int, duaId: Int) -> DuaBookmark? {
        let targetKey = "\(categoryId):\(duaId)"
        var descriptor = FetchDescriptor<DuaBookmark>(
            predicate: #Predicate { $0.duaKey == targetKey }
        )
        descriptor.fetchLimit = 2
        let matches = (try? modelContext.fetch(descriptor)) ?? []
        guard let keeper = matches.min(by: { $0.createdAt < $1.createdAt }) else { return nil }
        if matches.count > 1 {
            for dupe in matches where dupe !== keeper {
                modelContext.delete(dupe)
            }
            do { try modelContext.save() } catch { AppLogger.store.error("DuaBookmarkStore dedup save: \(error)") }
        }
        return keeper
    }

    private func fetchAll() -> [DuaBookmark] {
        (try? modelContext.fetch(FetchDescriptor<DuaBookmark>())) ?? []
    }
}
