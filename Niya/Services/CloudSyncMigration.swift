import Foundation
import SwiftData
import os

enum CloudSyncMigration {
    private static let migrationKey = StorageKey.cloudSyncMigrationCompleted

    static var defaultOldStoreURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("default.store")
    }

    /// Copies the pre-CloudKit local store into `container` once. The completion flag is
    /// set only after a successful save, and never when `container` is the in-memory
    /// fallback, so a failed or ephemeral attempt is retried on a later launch instead of
    /// permanently hiding the user's bookmarks. Retrying is safe: stores deduplicate on read.
    static func migrateIfNeeded(
        container: ModelContainer,
        oldStore: URL = defaultOldStoreURL,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: migrationKey), container.isPersistent else { return }

        guard FileManager.default.fileExists(atPath: oldStore.path) else {
            defaults.set(true, forKey: migrationKey)
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
            defaults.set(true, forKey: migrationKey)
            AppLogger.sync.info("Migration completed: \(counts)")
        } catch {
            AppLogger.sync.error("Migration failed (will retry next launch): \(error)")
        }
    }
}

extension ModelContainer {
    /// False for the in-memory fallback `ModelContainerFactory` uses when no on-disk store opens.
    var isPersistent: Bool {
        configurations.allSatisfy { !$0.isStoredInMemoryOnly }
    }
}
