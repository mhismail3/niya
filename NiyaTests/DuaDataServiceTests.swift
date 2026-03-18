import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("DuaDataService")
struct DuaDataServiceTests {

    @Test func initialState() {
        let service = DuaDataService()
        #expect(service.isLoaded == false)
        #expect(service.sections.isEmpty)
        #expect(service.categories.isEmpty)
        #expect(service.loadError == nil)
    }

    @Test func loadPopulatesData() async {
        let service = DuaDataService()
        await service.load()
        #expect(service.isLoaded == true)
        #expect(!service.sections.isEmpty)
        #expect(!service.categories.isEmpty)
    }

    @Test func searchDuas_returnsMatches() async {
        let service = DuaDataService()
        await service.load()
        let results = service.searchDuas(query: "morning")
        #expect(!results.isEmpty)
    }

    @Test func searchDuas_emptyForGibberish() async {
        let service = DuaDataService()
        await service.load()
        let results = service.searchDuas(query: "xyzzy123abc")
        #expect(results.isEmpty)
    }

    @Test func searchDuas_emptyQuery_returnsEmpty() {
        let service = DuaDataService()
        let results = service.searchDuas(query: "")
        #expect(results.isEmpty)
    }

    @Test func duaForValidId() async {
        let service = DuaDataService()
        await service.load()
        guard let firstCat = service.categories.first else { return }
        let duas = service.duas(for: firstCat.id)
        guard let firstDua = duas.first else { return }
        let found = service.dua(categoryId: firstCat.id, duaId: firstDua.id)
        #expect(found != nil)
        #expect(found?.id == firstDua.id)
    }

    @Test func duaForInvalidId_returnsNil() {
        let service = DuaDataService()
        let result = service.dua(categoryId: "nonexistent", duaId: "nope")
        #expect(result == nil)
    }
}
