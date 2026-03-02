import Foundation
import CoreLocation
import SwiftUI

@Observable
@MainActor
final class LocationService: NSObject {
    var currentLocation: UserLocation?
    var heading: Double = 0
    var headingAccuracy: Double = -1
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored
    @AppStorage(StorageKey.manualLocationData) private var manualLocationData: Data?

    var manualLocation: UserLocation? {
        get {
            guard let data = manualLocationData else { return nil }
            return try? JSONDecoder().decode(UserLocation.self, from: data)
        }
        set {
            if let loc = newValue {
                manualLocationData = try? JSONEncoder().encode(loc)
            } else {
                manualLocationData = nil
            }
        }
    }

    var effectiveLocation: UserLocation? {
        manualLocation ?? currentLocation
    }

    var isHeadingAvailable: Bool {
        CLLocationManager.headingAvailable()
    }

    var needsCalibration: Bool {
        headingAccuracy < 0
    }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var isUpdatingHeading = false
    @ObservationIgnored private var lastGeocodeDate: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startLocationUpdates() {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startHeading() {
        guard CLLocationManager.headingAvailable(), !isUpdatingHeading else { return }
        isUpdatingHeading = true
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        guard isUpdatingHeading else { return }
        isUpdatingHeading = false
        manager.stopUpdatingHeading()
    }

    func geocodeCity(_ query: String) async -> [UserLocation] {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            return placemarks.compactMap { placemark -> UserLocation? in
                guard let coord = placemark.location?.coordinate else { return nil }
                let name = [placemark.locality, placemark.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                let tzId = placemark.timeZone?.identifier ?? TimeZone.current.identifier
                return UserLocation(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    name: name.isEmpty ? "Unknown" : name,
                    timezoneIdentifier: tzId
                )
            }
        } catch {
            return []
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        Task { @MainActor in
            let shouldGeocode: Bool
            if let last = self.lastGeocodeDate {
                shouldGeocode = Date().timeIntervalSince(last) >= 30
            } else {
                shouldGeocode = true
            }

            let name: String
            if shouldGeocode {
                self.lastGeocodeDate = Date()
                let geocoder = CLGeocoder()
                if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
                   let pm = placemarks.first {
                    name = [pm.locality, pm.country].compactMap { $0 }.joined(separator: ", ")
                } else {
                    name = self.currentLocation?.name ?? String(format: "%.2f, %.2f", coord.latitude, coord.longitude)
                }
            } else {
                name = self.currentLocation?.name ?? String(format: "%.2f, %.2f", coord.latitude, coord.longitude)
            }

            let tzId = TimeZone.current.identifier
            self.currentLocation = UserLocation(
                latitude: coord.latitude,
                longitude: coord.longitude,
                name: name,
                timezoneIdentifier: tzId
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let accuracy = newHeading.headingAccuracy
        let trueH = newHeading.trueHeading
        let magH = newHeading.magneticHeading
        Task { @MainActor in
            self.headingAccuracy = accuracy
            self.heading = trueH >= 0 ? trueH : magH
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let shouldStart = status == .authorizedWhenInUse || status == .authorizedAlways
        Task { @MainActor in
            self.authorizationStatus = status
            if shouldStart {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
