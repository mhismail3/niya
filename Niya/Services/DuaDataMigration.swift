import Foundation
import SwiftData

enum DuaDataMigration {
    private static let migrationKey = "duaV2MigrationCompleted"

    /// Marks completion only after the map loads and the save succeeds, and never for the
    /// in-memory fallback container; otherwise old-format keys would be stranded forever.
    static func migrateIfNeeded(container: ModelContainer, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: migrationKey), container.isPersistent else { return }

        do {
            let map = try CompressedJSON.decode([String: String].self, resource: "dua_id_migration")
            let context = ModelContext(container)
            migrateBookmarks(modelContext: context, map: map)
            migrateRecents(modelContext: context, map: map)
            try context.save()
            defaults.set(true, forKey: migrationKey)
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
