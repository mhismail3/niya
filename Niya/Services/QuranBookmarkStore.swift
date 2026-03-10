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
        let all = fetchAll().sorted { $0.createdAt < $1.createdAt }
        var seen = Set<String>()
        var result: [QuranBookmark] = []
        var toDelete: [QuranBookmark] = []
        for item in all {
            if seen.insert(item.verseKey).inserted {
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

    private func fetch(surahId: Int, ayahId: Int) -> QuranBookmark? {
        let key = "\(surahId):\(ayahId)"
        let all = fetchAll()
        let matches = all.filter { $0.verseKey == key }
        guard let keeper = matches.min(by: { $0.createdAt < $1.createdAt }) else { return nil }
        if matches.count > 1 {
            for dupe in matches where dupe !== keeper {
                modelContext.delete(dupe)
            }
            try? modelContext.save()
        }
        return keeper
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
