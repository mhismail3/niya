import Foundation
import SwiftData

extension Notification.Name {
    static let bookmarkChanged = Notification.Name("bookmarkChanged")
}

@MainActor
final class QuranBookmarkStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isBookmarked(surahId: Int, ayahId: Int) -> Bool {
        fetch(surahId: surahId, ayahId: ayahId) != nil
    }

    func toggle(surahId: Int, ayahId: Int) {
        if let existing = fetch(surahId: surahId, ayahId: ayahId) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(QuranBookmark(surahId: surahId, ayahId: ayahId))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("QuranBookmarkStore save failed: \(error)") }
    }

    func setColor(_ color: BookmarkColor?, surahId: Int, ayahId: Int) {
        guard let bookmark = fetch(surahId: surahId, ayahId: ayahId) else { return }
        bookmark.bookmarkColor = color
        do { try modelContext.save() } catch { AppLogger.store.error("QuranBookmarkStore save failed: \(error)") }
        NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
    }

    func allBookmarks() -> [QuranBookmark] {
        fetchAll().sorted { $0.createdAt > $1.createdAt }
    }

    private func fetch(surahId: Int, ayahId: Int) -> QuranBookmark? {
        let key = "\(surahId):\(ayahId)"
        var descriptor = FetchDescriptor<QuranBookmark>(
            predicate: #Predicate<QuranBookmark> { $0.verseKey == key }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func fetchAll() -> [QuranBookmark] {
        do {
            let results = try modelContext.fetch(FetchDescriptor<QuranBookmark>())
            return results
        } catch {
            AppLogger.store.error("QuranBookmarkStore fetchAll failed: \(error)")
            return []
        }
    }
}
