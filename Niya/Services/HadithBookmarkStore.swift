import Foundation
import SwiftData

@MainActor
final class HadithBookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isBookmarked(collectionId: String, hadithId: Int) -> Bool {
        let key = "\(collectionId):\(hadithId)"
        return fetchAll().contains { $0.hadithKey == key }
    }

    func toggle(collectionId: String, hadithId: Int) {
        let key = "\(collectionId):\(hadithId)"
        if let existing = fetchAll().first(where: { $0.hadithKey == key }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(HadithBookmark(collectionId: collectionId, hadithId: hadithId))
        }
        try? modelContext.save()
    }

    func allBookmarks() -> [HadithBookmark] {
        fetchAll().sorted { $0.createdAt > $1.createdAt }
    }

    func bookmarks(for collectionId: String) -> [HadithBookmark] {
        fetchAll().filter { $0.collectionId == collectionId }.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchAll() -> [HadithBookmark] {
        (try? modelContext.fetch(FetchDescriptor<HadithBookmark>())) ?? []
    }
}
