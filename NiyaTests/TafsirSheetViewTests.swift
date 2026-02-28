import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TafsirSheetView")
struct TafsirSheetViewTests {

    @Test func defaultEditionIsIbnKathir() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedTafsir")
        let raw = defaults.string(forKey: "selectedTafsir") ?? TafsirEdition.ibnKathir.rawValue
        let edition = TafsirEdition(rawValue: raw)
        #expect(edition == .ibnKathir)
    }
}
