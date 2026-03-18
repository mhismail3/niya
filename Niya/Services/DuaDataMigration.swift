import Foundation
import SwiftData

@MainActor
enum DuaDataMigration {
    private static let migrationKey = "duaV2MigrationCompleted"

    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: migrationKey) }

        guard let map = loadMigrationMap() else { return }

        migrateBookmarks(modelContext: modelContext, map: map)
        migrateRecents(modelContext: modelContext, map: map)

        do {
            try modelContext.save()
        } catch {
            AppLogger.store.error("DuaDataMigration save failed: \(error)")
        }
    }

    private static func loadMigrationMap() -> [String: String]? {
        guard let url = Bundle.main.url(forResource: "dua_id_migration", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return map
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
