import Foundation
import SwiftData

@MainActor
final class HadithBookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isBookmarked(collectionId: String, hadithId: Int) -> Bool {
        fetchByKey(collectionId: collectionId, hadithId: hadithId) != nil
    }

    func toggle(collectionId: String, hadithId: Int) {
        if let existing = fetchByKey(collectionId: collectionId, hadithId: hadithId) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(HadithBookmark(collectionId: collectionId, hadithId: hadithId))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("HadithBookmarkStore save failed: \(error)") }
    }

    func setColor(_ color: BookmarkColor?, collectionId: String, hadithId: Int) {
        guard let bookmark = fetchByKey(collectionId: collectionId, hadithId: hadithId) else { return }
        bookmark.bookmarkColor = color
        do { try modelContext.save() } catch { AppLogger.store.error("HadithBookmarkStore save failed: \(error)") }
        NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
    }

    func allBookmarks() -> [HadithBookmark] {
        let all = fetchAll().sorted { $0.createdAt < $1.createdAt }
        var seen = Set<String>()
        var result: [HadithBookmark] = []
        var toDelete: [HadithBookmark] = []
        for item in all {
            if seen.insert(item.hadithKey).inserted {
                result.append(item)
            } else {
                toDelete.append(item)
            }
        }
        if !toDelete.isEmpty {
            for dupe in toDelete { modelContext.delete(dupe) }
            try? modelContext.save()
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    func bookmarks(for collectionId: String) -> [HadithBookmark] {
        allBookmarks().filter { $0.collectionId == collectionId }
    }

    private func fetchByKey(collectionId: String, hadithId: Int) -> HadithBookmark? {
        let key = "\(collectionId):\(hadithId)"
        let all = fetchAll()
        let matches = all.filter { $0.hadithKey == key }
        guard let keeper = matches.min(by: { $0.createdAt < $1.createdAt }) else { return nil }
        if matches.count > 1 {
            for dupe in matches where dupe !== keeper {
                modelContext.delete(dupe)
            }
            try? modelContext.save()
        }
        return keeper
    }

    private func fetchAll() -> [HadithBookmark] {
        (try? modelContext.fetch(FetchDescriptor<HadithBookmark>())) ?? []
    }
}
