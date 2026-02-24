import Foundation

@Observable
@MainActor
final class SurahListViewModel {
    var searchQuery = ""
    private let dataService: QuranDataService

    init(dataService: QuranDataService) {
        self.dataService = dataService
    }

    var filteredSurahs: [Surah] {
        dataService.searchSurahs(query: searchQuery)
    }

    var isLoaded: Bool { dataService.isLoaded }
    var loadError: String? { dataService.loadError }

    func load() async {
        await dataService.load()
    }
}
