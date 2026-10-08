import Foundation
import SwiftData

enum DuaDataMigration {
    /// Re-run on every launch: older devices may sync legacy keys after this device's first import.
    static func migrateIfNeeded(container: ModelContainer) {
        guard container.isPersistent else { return }

        do {
            let map = try CompressedJSON.decode([String: String].self, resource: "dua_id_migration")
            let context = ModelContext(container)
            migrateBookmarks(modelContext: context, map: map)
            migrateRecents(modelContext: context, map: map)
            try context.save()
        } catch {
            AppLogger.store.error("DuaDataMigration failed (will retry next launch): \(error)")
        }
    }

    private static func migrateBookmarks(modelContext: ModelContext, map: [String: String]) {
        let bookmarks = (try? modelContext.fetch(FetchDescriptor<DuaBookmark>())) ?? []
        for bookmark in bookmarks {
            if let newKey = map[bookmark.duaKey] {
                bookmark.duaKey = newKey
            } else if looksLikeOldFormat(bookmark.duaKey) {
                modelContext.delete(bookmark)
            }
        }
    }

    private static func migrateRecents(modelContext: ModelContext, map: [String: String]) {
        let recents = (try? modelContext.fetch(FetchDescriptor<RecentDua>())) ?? []
        for recent in recents {
            if let newKey = map[recent.duaKey] {
                recent.duaKey = newKey
            } else if looksLikeOldFormat(recent.duaKey) {
                modelContext.delete(recent)
            }
        }
    }

    private static func looksLikeOldFormat(_ key: String) -> Bool {
        let parts = key.components(separatedBy: ":")
        guard parts.count == 2 else { return false }
        return Int(parts[0]) != nil && Int(parts[1]) != nil
    }
}
