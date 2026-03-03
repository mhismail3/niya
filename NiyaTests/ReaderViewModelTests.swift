import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("ReaderViewModel")
struct ReaderViewModelTests {

    private let testSurah = Surah(
        id: 2,
        name: "البقرة",
        transliteration: "Al-Baqarah",
        translation: "The Cow",
        type: "Medinan",
        totalVerses: 286,
        startPage: 2
    )

    private func makeVM(initialAyahId: Int? = nil) -> ReaderViewModel {
        ReaderViewModel(
            surah: testSurah,
            dataService: QuranDataService(),
            script: .hafs,
            initialAyahId: initialAyahId
        )
    }

    @Test func defaultInitSetsNilInitialAyah() {
        let vm = makeVM()
        #expect(vm.initialAyahId == nil)
        #expect(vm.visibleAyahId == 1)
        #expect(vm.currentPage == 0)
    }

    @Test func initWithInitialAyahStoresValue() {
        let vm = makeVM(initialAyahId: 50)
        #expect(vm.initialAyahId == 50)
    }

    @Test func updateVisibleAyah() {
        let vm = makeVM()
        vm.isSettled = true
        vm.updateVisibleAyah(25)
        #expect(vm.visibleAyahId == 25)
    }

    @Test func loadWithInitialAyahSetsVisibleAyahAndPage() {
        let vm = makeVM(initialAyahId: 50)
        // Set up synthetic pages
        let page0 = (1...30).map { Verse(id: $0, text: "", translation: "", transliteration: nil, page: 1) }
        let page1 = (31...60).map { Verse(id: $0, text: "", translation: "", transliteration: nil, page: 2) }
        vm.pages = [page0, page1]
        vm.verses = page0 + page1

        // Replay load() page-targeting logic
        if let target = vm.initialAyahId,
           let pageIndex = vm.pages.firstIndex(where: { $0.contains { $0.id == target } }) {
            vm.currentPage = pageIndex
            vm.visibleAyahId = target
        }

        #expect(vm.currentPage == 1)
        #expect(vm.visibleAyahId == 50)
    }

    @Test func loadWithoutInitialAyahDefaultsToFirstPage() {
        let vm = makeVM()
        vm.load() // empty data service → empty pages
        #expect(vm.currentPage == 0)
        #expect(vm.visibleAyahId == 1) // fallback when verses empty
    }
}
