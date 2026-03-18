import Foundation
import SwiftData
import os

@MainActor
enum CloudSyncMigration {
    private static let migrationKey = StorageKey.cloudSyncMigrationCompleted

    static func migrateIfNeeded(container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldStore = appSupport.appendingPathComponent("default.store")

        guard FileManager.default.fileExists(atPath: oldStore.path) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        do {
            let oldConfig = ModelConfiguration(url: oldStore, cloudKitDatabase: .none)
            let oldContainer = try ModelContainer(
                for: QuranBookmark.self, HadithBookmark.self, DuaBookmark.self,
                     ReadingPosition.self, RecentHadith.self, RecentDua.self,
                     RecentSearch.self, AudioDownload.self,
                configurations: oldConfig
            )
            let oldContext = ModelContext(oldContainer)

            // Use a separate context so failed saves don't pollute mainContext
            let newContext = ModelContext(container)

            var counts: [String: Int] = [:]

            let qb = try oldContext.fetch(FetchDescriptor<QuranBookmark>())
            for old in qb {
                let new = QuranBookmark(surahId: old.surahId, ayahId: old.ayahId, createdAt: old.createdAt)
                new.colorTag = old.colorTag
                newContext.insert(new)
            }
            counts["QuranBookmark"] = qb.count

            let hb = try oldContext.fetch(FetchDescriptor<HadithBookmark>())
            for old in hb {
                let new = HadithBookmark(collectionId: old.collectionId, hadithId: old.hadithId, createdAt: old.createdAt)
                new.colorTag = old.colorTag
                newContext.insert(new)
            }
            counts["HadithBookmark"] = hb.count

            let db = try oldContext.fetch(FetchDescriptor<DuaBookmark>())
            for old in db {
                let new = DuaBookmark(categoryId: old.categorySlug, duaId: old.duaStringId, createdAt: old.createdAt)
                new.colorTag = old.colorTag
                newContext.insert(new)
            }
            counts["DuaBookmark"] = db.count

            let rp = try oldContext.fetch(FetchDescriptor<ReadingPosition>())
            for old in rp {
                newContext.insert(ReadingPosition(surahId: old.surahId, lastAyahId: old.lastAyahId, lastReadAt: old.lastReadAt))
            }
            counts["ReadingPosition"] = rp.count

            let rh = try oldContext.fetch(FetchDescriptor<RecentHadith>())
            for old in rh {
                newContext.insert(RecentHadith(collectionId: old.collectionId, hadithId: old.hadithId, hasGrades: old.hasGrades, visitedAt: old.visitedAt))
            }
            counts["RecentHadith"] = rh.count

            let rd = try oldContext.fetch(FetchDescriptor<RecentDua>())
            for old in rd {
                newContext.insert(RecentDua(categoryId: old.categorySlug, duaId: old.duaStringId, visitedAt: old.visitedAt))
            }
            counts["RecentDua"] = rd.count

            let rs = try oldContext.fetch(FetchDescriptor<RecentSearch>())
            for old in rs {
                newContext.insert(RecentSearch(query: old.query, surahId: old.surahId, createdAt: old.createdAt))
            }
            counts["RecentSearch"] = rs.count

            try newContext.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            AppLogger.sync.info("Migration completed: \(counts)")
        } catch {
            // Set the flag even on failure — retrying every launch would
            // resurrect cleared data into the in-memory context each time.
            // Users who upgrade from local-only lose nothing: the old
            // default.store is still on disk and the new CloudSync store
            // works independently.
            UserDefaults.standard.set(true, forKey: migrationKey)
            AppLogger.sync.error("Migration failed (will not retry): \(error)")
        }
    }
}
