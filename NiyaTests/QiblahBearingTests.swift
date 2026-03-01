import Foundation
import Testing
@testable import Niya

@Suite("Qiblah Bearing")
struct QiblahBearingTests {

    private let tolerance = 1.5 // degrees

    @Test func newYorkToMecca() {
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")
        let bearing = PrayerTimeCalculator.qiblahBearing(from: loc)
        // New York to Mecca: ~58.5 degrees NE
        #expect(abs(bearing - 58.5) < tolerance, "Got \(bearing)")
    }

    @Test func londonToMecca() {
        let loc = UserLocation(latitude: 51.5074, longitude: -0.1278, name: "London", timezoneIdentifier: "Europe/London")
        let bearing = PrayerTimeCalculator.qiblahBearing(from: loc)
        // London to Mecca: ~119 degrees ESE
        #expect(abs(bearing - 119.0) < tolerance, "Got \(bearing)")
    }

    @Test func tokyoToMecca() {
        let loc = UserLocation(latitude: 35.6762, longitude: 139.6503, name: "Tokyo", timezoneIdentifier: "Asia/Tokyo")
        let bearing = PrayerTimeCalculator.qiblahBearing(from: loc)
        // Tokyo to Mecca: ~293 degrees WNW
        #expect(abs(bearing - 293.0) < 2.0, "Got \(bearing)")
    }

    @Test func sydneyToMecca() {
        let loc = UserLocation(latitude: -33.8688, longitude: 151.2093, name: "Sydney", timezoneIdentifier: "Australia/Sydney")
        let bearing = PrayerTimeCalculator.qiblahBearing(from: loc)
        // Sydney to Mecca: ~278 degrees W
        #expect(abs(bearing - 278.0) < 3.0, "Got \(bearing)")
    }

    @Test func meccaToMeccaBearingIsZeroish() {
        let bearing = PrayerTimeCalculator.qiblahBearing(from: .mecca)
        // At the Kaaba the bearing is 0 (atan2(0,0) = 0)
        #expect(bearing < 1 || bearing > 359, "Got \(bearing)")
    }

    @Test func fijiAntimeridian() {
        let loc = UserLocation(latitude: -18.1416, longitude: 178.4419, name: "Suva, Fiji", timezoneIdentifier: "Pacific/Fiji")
        let bearing = PrayerTimeCalculator.qiblahBearing(from: loc)
        // Should be roughly west-northwest ~281
        #expect(bearing > 260 && bearing < 300, "Got \(bearing)")
    }

    @Test func northPole() {
        let loc = UserLocation(latitude: 89.99, longitude: 0, name: "North Pole", timezoneIdentifier: "UTC")
        let bearing = PrayerTimeCalculator.qiblahBearing(from: loc)
        // From the north pole, Mecca is roughly south at ~220 (accounting for longitude offset)
        #expect(bearing > 100 && bearing < 250, "Got \(bearing)")
    }
}
