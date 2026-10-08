import Foundation
import CoreLocation

struct UserLocation: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let name: String
    let timezoneIdentifier: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    static let mecca = UserLocation(
        latitude: 21.4225,
        longitude: 39.8262,
        name: "Mecca, Saudi Arabia",
        timezoneIdentifier: "Asia/Riyadh"
    )
}
