import Foundation
import Testing
import MapKit
@testable import Niya

@Suite("Location Search")
struct LocationSearchTests {

    @MainActor
    @Test func updateSearchQuerySetsCompleterFragment() {
        let service = LocationService()
        service.updateSearchQuery("Kirk")
        #expect(service.isSearching == true)
    }

    @MainActor
    @Test func emptyQueryClearsCompletions() {
        let service = LocationService()
        service.updateSearchQuery("London")
        service.updateSearchQuery("")
        #expect(service.searchCompletions.isEmpty)
        #expect(service.isSearching == false)
    }

    @MainActor
    @Test func stopSearchClearsState() {
        let service = LocationService()
        service.updateSearchQuery("Tokyo")
        service.stopSearch()
        #expect(service.searchCompletions.isEmpty)
        #expect(service.isSearching == false)
    }

    @MainActor
    @Test func initialStateIsEmpty() {
        let service = LocationService()
        #expect(service.searchCompletions.isEmpty)
        #expect(service.isSearching == false)
    }
}
