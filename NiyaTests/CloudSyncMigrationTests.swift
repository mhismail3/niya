import Foundation
import SwiftData
import Testing
@testable import Niya

@MainActor
@Suite("CloudSyncMigration", .serialized)
final class CloudSyncMigrationTests {
    private let directory: URL
    private let defaults: UserDefaults
    private let key = StorageKey.cloudSyncMigrationCompleted

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("niya-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: "niya-tests-\(UUID().uuidString)"))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore(_ name: String) throws -> ModelContainer {
        let models = ModelContainerFactory.syncedModels + ModelContainerFactory.localModels
        return try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(url: directory.appendingPathComponent(name), cloudKitDatabase: .none)
        )
    }

    @Test func copiesOldStoreAndMarksCompletion() throws {
        let old = try makeStore("default.store")
        old.mainContext.insert(QuranBookmark(surahId: 2, ayahId: 255))
        try old.mainContext.save()
        let target = try makeStore("CloudSync.store")

        CloudSyncMigration.migrateIfNeeded(
            container: target, oldStore: directory.appendingPathComponent("default.store"), defaults: defaults
        )

        let copied = try ModelContext(target).fetch(FetchDescriptor<QuranBookmark>())
        #expect(copied.map(\.ayahId) == [255])
        #expect(defaults.bool(forKey: key))
    }

    @Test func unreadableOldStoreIsRetriedLater() throws {
        let oldStore = directory.appendingPathComponent("default.store")
        try Data("not a database".utf8).write(to: oldStore)

        CloudSyncMigration.migrateIfNeeded(container: try makeStore("CloudSync.store"), oldStore: oldStore, defaults: defaults)

        #expect(defaults.bool(forKey: key) == false)
    }

    @Test func neverMigratesIntoInMemoryFallback() throws {
        let old = try makeStore("default.store")
        old.mainContext.insert(QuranBookmark(surahId: 1, ayahId: 1))
        try old.mainContext.save()
        let fallback = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)

        CloudSyncMigration.migrateIfNeeded(
            container: fallback, oldStore: directory.appendingPathComponent("default.store"), defaults: defaults
        )

        #expect(defaults.bool(forKey: key) == false)
        #expect(try ModelContext(fallback).fetchCount(FetchDescriptor<QuranBookmark>()) == 0)
    }

    @Test func freshInstallMarksCompletionWithoutCopying() throws {
        CloudSyncMigration.migrateIfNeeded(
            container: try makeStore("CloudSync.store"),
            oldStore: directory.appendingPathComponent("missing.store"),
            defaults: defaults
        )

        #expect(defaults.bool(forKey: key))
    }
}
