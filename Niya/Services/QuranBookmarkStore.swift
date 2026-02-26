import Foundation
import SwiftData

@MainActor
final class QuranBookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isBookmarked(surahId: Int, ayahId: Int) -> Bool {
        let key = "\(surahId):\(ayahId)"
        return fetchAll().contains { $0.verseKey == key }
    }

    func toggle(surahId: Int, ayahId: Int) {
        let key = "\(surahId):\(ayahId)"
        if let existing = fetchAll().first(where: { $0.verseKey == key }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(QuranBookmark(surahId: surahId, ayahId: ayahId))
        }
        try? modelContext.save()
    }

    func allBookmarks() -> [QuranBookmark] {
        fetchAll().sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchAll() -> [QuranBookmark] {
        (try? modelContext.fetch(FetchDescriptor<QuranBookmark>())) ?? []
    }
}
