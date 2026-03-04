import Foundation
import Testing
@testable import Niya

@Suite("Location Name Formatting")
struct LocationNameFormattingTests {

    @Test func usCityIncludesState() {
        let name = LocationService.formatLocationName(
            locality: "Kirkland",
            administrativeArea: "WA",
            country: "United States"
        )
        #expect(name == "Kirkland, WA, United States")
    }

    @Test func nonUSCityWithAdminArea() {
        let name = LocationService.formatLocationName(
            locality: "Toronto",
            administrativeArea: "Ontario",
            country: "Canada"
        )
        #expect(name == "Toronto, Ontario, Canada")
    }

    @Test func adminAreaMatchesLocalityIsSkipped() {
        let name = LocationService.formatLocationName(
            locality: "Tokyo",
            administrativeArea: "Tokyo",
            country: "Japan"
        )
        #expect(name == "Tokyo, Japan")
    }

    @Test func nilAdminArea() {
        let name = LocationService.formatLocationName(
            locality: "London",
            administrativeArea: nil,
            country: "United Kingdom"
        )
        #expect(name == "London, United Kingdom")
    }

    @Test func nilLocality() {
        let name = LocationService.formatLocationName(
            locality: nil,
            administrativeArea: "Bavaria",
            country: "Germany"
        )
        #expect(name == "Bavaria, Germany")
    }

    @Test func onlyCountry() {
        let name = LocationService.formatLocationName(
            locality: nil,
            administrativeArea: nil,
            country: "France"
        )
        #expect(name == "France")
    }

    @Test func allNil() {
        let name = LocationService.formatLocationName(
            locality: nil,
            administrativeArea: nil,
            country: nil
        )
        #expect(name == "Unknown")
    }

    @Test func localityAndCountryOnly() {
        let name = LocationService.formatLocationName(
            locality: "Dubai",
            administrativeArea: nil,
            country: "United Arab Emirates"
        )
        #expect(name == "Dubai, United Arab Emirates")
    }
}
