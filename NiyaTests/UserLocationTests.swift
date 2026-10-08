import Foundation
import Testing
import CoreLocation
@testable import Niya

@Suite("UserLocation")
struct UserLocationTests {

    @Test func codableRoundTrip() throws {
        let loc = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")
        let data = try JSONEncoder().encode(loc)
        let decoded = try JSONDecoder().decode(UserLocation.self, from: data)
        #expect(decoded == loc)
    }

    @Test func meccaConstant() {
        let mecca = UserLocation.mecca
        #expect(abs(mecca.latitude - 21.4225) < 0.01)
        #expect(abs(mecca.longitude - 39.8262) < 0.01)
        #expect(mecca.name.contains("Mecca"))
        #expect(mecca.timezoneIdentifier == "Asia/Riyadh")
    }

    @Test func coordinateProperty() {
        let loc = UserLocation(latitude: 51.5074, longitude: -0.1278, name: "London", timezoneIdentifier: "Europe/London")
        let coord = loc.coordinate
        #expect(abs(coord.latitude - 51.5074) < 0.0001)
        #expect(abs(coord.longitude - (-0.1278)) < 0.0001)
    }

    @Test func validTimezone() {
        let loc = UserLocation(latitude: 35.6762, longitude: 139.6503, name: "Tokyo", timezoneIdentifier: "Asia/Tokyo")
        #expect(loc.timeZone.identifier == "Asia/Tokyo")
    }

    @Test func prayerRecalculationIgnoresRenamesAndSmallMoves() {
        let original = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "New York", timezoneIdentifier: "America/New_York")
        let renamed = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "Manhattan, NY", timezoneIdentifier: "America/New_York")
        let nearby = UserLocation(latitude: 40.7180, longitude: -74.0060, name: "Nearby", timezoneIdentifier: "America/New_York")
        let moved = UserLocation(latitude: 40.73, longitude: -74.0060, name: "Moved", timezoneIdentifier: "America/New_York")
        let otherZone = UserLocation(latitude: 40.7128, longitude: -74.0060, name: "Same", timezoneIdentifier: "Asia/Tokyo")

        #expect(!LocationService.requiresPrayerRecalculation(from: original, to: renamed))
        #expect(!LocationService.requiresPrayerRecalculation(from: original, to: nearby))
        #expect(LocationService.requiresPrayerRecalculation(from: original, to: moved))
        #expect(LocationService.requiresPrayerRecalculation(from: original, to: otherZone))
    }

    @Test func prayerDayChangeUsesLocationTimeZone() {
        let formatter = ISO8601DateFormatter()
        let previous = formatter.date(from: "2024-01-01T07:30:00Z")!
        let now = formatter.date(from: "2024-01-01T08:30:00Z")!
        #expect(!PrayerTimeService.isDifferentLocalDay(previous, now: now, timeZone: TimeZone(identifier: "Asia/Tokyo")!))
        #expect(PrayerTimeService.isDifferentLocalDay(previous, now: now, timeZone: TimeZone(identifier: "America/Los_Angeles")!))
    }

    @Test func invalidTimezoneFallsBackToCurrent() {
        let loc = UserLocation(latitude: 0, longitude: 0, name: "Nowhere", timezoneIdentifier: "Invalid/Zone")
        #expect(loc.timeZone == .current)
    }
}
