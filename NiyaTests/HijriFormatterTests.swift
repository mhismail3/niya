import Testing
import Foundation
@testable import Niya

@Suite("HijriFormatter")
struct HijriFormatterTests {
    @Test("All 12 month names are valid")
    func allMonthNames() {
        let names = HijriFormatter.monthNames
        #expect(names.count == 12)
        #expect(names[0] == "Muharram")
        #expect(names[8] == "Ramadan")
        #expect(names[11] == "Dhul Hijjah")
    }

    @Test("Format includes year and AH")
    func formatWithYear() {
        let result = HijriFormatter.format(date: Date(), includeYear: true)
        #expect(result.contains("AH"))
        #expect(!result.isEmpty)
    }

    @Test("Short format excludes year")
    func formatWithoutYear() {
        let result = HijriFormatter.format(date: Date(), includeYear: false)
        #expect(!result.contains("AH"))
        #expect(!result.isEmpty)
    }

    @Test("Known date format structure")
    func formatStructure() {
        let result = HijriFormatter.format(date: Date())
        let parts = result.split(separator: " ")
        #expect(parts.count >= 4) // day monthName year AH
        #expect(parts.last == "AH")
        #expect(Int(parts.first!) != nil) // day is a number
    }

    @Test("Month name matches Islamic calendar")
    func monthNameConsistency() {
        let hijriCal = Calendar(identifier: .islamicUmmAlQura)
        let month = hijriCal.component(.month, from: Date())
        let result = HijriFormatter.format(date: Date())
        let expectedMonth = HijriFormatter.monthNames[month - 1]
        #expect(result.contains(expectedMonth))
    }
}
