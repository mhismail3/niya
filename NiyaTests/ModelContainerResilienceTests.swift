import Testing
import SwiftData
@testable import Niya

@MainActor
struct ModelContainerResilienceTests {
    @Test func cloudKitFallbackCreatesLocalContainer() throws {
        let container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
        let context = container.mainContext

        let allTypes: [any PersistentModel.Type] = ModelContainerFactory.syncedModels + ModelContainerFactory.localModels
        #expect(allTypes.count == 8)

        let bookmarks = try context.fetch(FetchDescriptor<QuranBookmark>())
        #expect(bookmarks.isEmpty)
    }

    @Test func fallbackContainerPreservesStoreNames() throws {
        let container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
        let configs = container.configurations
        let names = Set(configs.map(\.name))
        #expect(names.contains("CloudSync"))
        #expect(names.contains("LocalOnly"))
    }

    @Test func fallbackContainerSupportsAllCRUD() throws {
        let container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
        let context = container.mainContext

        let bookmark = QuranBookmark(surahId: 1, ayahId: 1)
        context.insert(bookmark)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<QuranBookmark>())
        #expect(fetched.count == 1)
        #expect(fetched[0].surahId == 1)

        context.delete(fetched[0])
        try context.save()

        let after = try context.fetch(FetchDescriptor<QuranBookmark>())
        #expect(after.isEmpty)
    }

    @Test func containerCreationWithBothConfigsSucceeds() throws {
        let container = try ModelContainerFactory.makeContainer(cloudKit: .none, inMemory: true)
        #expect(container.configurations.count == 2)

        let context = container.mainContext
        let position = ReadingPosition(surahId: 2, lastAyahId: 10)
        context.insert(position)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ReadingPosition>())
        #expect(fetched.count == 1)

        let download = AudioDownload(surahId: 1, localFileName: "test.mp3")
        context.insert(download)
        try context.save()

        let downloads = try context.fetch(FetchDescriptor<AudioDownload>())
        #expect(downloads.count == 1)
    }

    @Test func createReturnsWorkingContainer() {
        let container = ModelContainerFactory.create()
        #expect(container.configurations.count == 2)
    }
}
