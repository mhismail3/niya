import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("SurahListViewModel")
struct SurahListViewModelTests {

    private static let testSurahs = [
        Surah(id: 1, name: "الفاتحة", transliteration: "Al-Fatihah",
              translation: "The Opener", type: "Meccan", totalVerses: 7, startPage: 1),
        Surah(id: 2, name: "البقرة", transliteration: "Al-Baqarah",
              translation: "The Cow", type: "Medinan", totalVerses: 286, startPage: 2),
        Surah(id: 114, name: "الناس", transliteration: "An-Nas",
              translation: "Mankind", type: "Meccan", totalVerses: 6, startPage: 604),
    ]

    private func makeVM() -> SurahListViewModel {
        let ds = QuranDataService()
        ds.surahs = Self.testSurahs
        return SurahListViewModel(dataService: ds)
    }

    @Test func emptyQuery_returnsAll() {
        let vm = makeVM()
        vm.searchQuery = ""
        #expect(vm.filteredSurahs.count == 3)
    }

    @Test func filterByEnglishName() {
        let vm = makeVM()
        vm.searchQuery = "cow"
        #expect(vm.filteredSurahs.count == 1)
        #expect(vm.filteredSurahs[0].id == 2)
    }

    @Test func filterByArabicName() {
        let vm = makeVM()
        vm.searchQuery = "الفاتحة"
        #expect(vm.filteredSurahs.count == 1)
        #expect(vm.filteredSurahs[0].id == 1)
    }

    @Test func filterByNumber() {
        let vm = makeVM()
        vm.searchQuery = "114"
        #expect(vm.filteredSurahs.count == 1)
        #expect(vm.filteredSurahs[0].id == 114)
    }

    @Test func filterNoResults() {
        let vm = makeVM()
        vm.searchQuery = "zzzzz"
        #expect(vm.filteredSurahs.isEmpty)
    }
}
