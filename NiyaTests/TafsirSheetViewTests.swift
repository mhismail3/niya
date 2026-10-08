import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirSheetView")
struct TafsirSheetViewTests {

    @Test func defaultEditionIsIbnKathir() {
        let defaults = UserDefaults(suiteName: "NiyaTests.TafsirSheetView.\(UUID().uuidString)")!
        let view = TafsirSheetView(surahId: 1, ayahId: 1, surahName: "Al-Fatihah", defaults: defaults)
        #expect(view.surahId == 1)
        #expect(defaults.string(forKey: StorageKey.selectedTafsir) == nil)
    }
}
