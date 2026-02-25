import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("HadithDataService")
struct HadithDataServiceTests {

    @Test func initialState() {
        let service = HadithDataService()
        #expect(service.isLoaded == false)
        #expect(service.collections.isEmpty)
        #expect(service.loadError == nil)
    }

    @Test func collectionNotLoaded() {
        let service = HadithDataService()
        #expect(service.isCollectionLoaded("bukhari") == false)
    }

    @Test func chaptersForUnloaded() {
        let service = HadithDataService()
        #expect(service.chapters(for: "bukhari").isEmpty)
    }

    @Test func hadithsForUnloaded() {
        let service = HadithDataService()
        #expect(service.hadiths(for: "bukhari").isEmpty)
    }

    @Test func searchEmptyQuery() {
        let service = HadithDataService()
        #expect(service.searchHadiths(query: "").isEmpty)
    }

    @Test func searchWhitespaceQuery() {
        let service = HadithDataService()
        #expect(service.searchHadiths(query: "   ").isEmpty)
    }

    @Test func searchNoLoadedCollections() {
        let service = HadithDataService()
        #expect(service.searchHadiths(query: "test").isEmpty)
    }

    @Test func loadedCollectionCountInitial() {
        let service = HadithDataService()
        #expect(service.loadedCollectionCount == 0)
    }
}
