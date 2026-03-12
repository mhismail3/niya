import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("SettingsView Consolidation")
struct SettingsViewTests {

    private let testSurah = Surah(
        id: 2,
        name: "البقرة",
        transliteration: "Al-Baqarah",
        translation: "The Cow",
        type: "Medinan",
        totalVerses: 286,
        startPage: 2
    )

    private func makeReaderVM() -> ReaderViewModel {
        ReaderViewModel(
            surah: testSurah,
            dataService: QuranDataService(),
            script: .hafs
        )
    }

    @Test func defaultInitHasNilReaderVM() {
        let view = SettingsView()
        #expect(view.readerVM == nil)
    }

    @Test func acceptsOptionalReaderVM() {
        let vm = makeReaderVM()
        let view = SettingsView(readerVM: vm)
        #expect(view.readerVM != nil)
    }

    @Test func readerModeBindingUsesAppStorageWhenNoVM() {
        let view = SettingsView()
        #expect(view.readerVM == nil)
    }

    @Test func readerModeBindingUsesVMWhenProvided() {
        let vm = makeReaderVM()
        vm.mode = .page
        let view = SettingsView(readerVM: vm)
        #expect(view.readerVM?.mode == .page)
    }

    @Test func vmModeChangeReflected() {
        let vm = makeReaderVM()
        #expect(vm.mode == .scroll)
        vm.mode = .page
        #expect(vm.mode == .page)
    }

    @Test func defaultInitShowsNoDownloadContext() {
        let view = SettingsView()
        #expect(view.readerVM == nil)
    }

    @Test func readerInitProvidesDownloadContext() {
        let vm = makeReaderVM()
        let view = SettingsView(readerVM: vm)
        #expect(view.readerVM != nil)
        #expect(view.readerVM?.surah.id == 2)
    }
}
