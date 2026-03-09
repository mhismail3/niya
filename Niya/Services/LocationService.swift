import Foundation
import CoreLocation
import MapKit
import SwiftUI

@Observable
@MainActor
final class LocationService: NSObject {
    var currentLocation: UserLocation?
    var heading: Double = 0
    var headingAccuracy: Double = -1
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var searchCompletions: [MKLocalSearchCompletion] = []
    var isSearching = false

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
    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var isUpdatingHeading = false
    @ObservationIgnored private var lastGeocodeDate: Date?
    @ObservationIgnored private var smoothedHeading: Double = 0
    @ObservationIgnored private var hasInitialHeading = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        manager.headingFilter = 1
        authorizationStatus = manager.authorizationStatus
        completer.delegate = self
        completer.resultTypes = .address
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
        hasInitialHeading = false
        manager.stopUpdatingHeading()
    }

    // MARK: - Location Search

    func updateSearchQuery(_ query: String) {
        guard !query.isEmpty else {
            stopSearch()
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func stopSearch() {
        completer.cancel()
        searchCompletions = []
        isSearching = false
    }

    func selectCompletion(_ completion: MKLocalSearchCompletion) async -> UserLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let pm = item.placemark
            let name = Self.formatLocationName(
                locality: pm.locality,
                administrativeArea: pm.administrativeArea,
                country: pm.country
            )
            let tzId = pm.timeZone?.identifier ?? TimeZone.current.identifier
            return UserLocation(
                latitude: pm.coordinate.latitude,
                longitude: pm.coordinate.longitude,
                name: name,
                timezoneIdentifier: tzId
            )
        } catch {
            return nil
        }
    }

    // MARK: - Name Formatting

    nonisolated static func formatLocationName(
        locality: String?,
        administrativeArea: String?,
        country: String?
    ) -> String {
        var parts: [String] = []
        if let locality { parts.append(locality) }
        if let admin = administrativeArea, admin != locality {
            parts.append(admin)
        }
        if let country { parts.append(country) }
        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension LocationService: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchCompletions = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
    }
}

// MARK: - CLLocationManagerDelegate

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
                    name = Self.formatLocationName(
                        locality: pm.locality,
                        administrativeArea: pm.administrativeArea,
                        country: pm.country
                    )
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
        let raw = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.headingAccuracy = accuracy
            if !self.hasInitialHeading {
                self.smoothedHeading = raw
                self.hasInitialHeading = true
            } else {
                var delta = raw - self.smoothedHeading
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                let alpha: Double = 0.25
                self.smoothedHeading += alpha * delta
                self.smoothedHeading = self.smoothedHeading.truncatingRemainder(dividingBy: 360)
                if self.smoothedHeading < 0 { self.smoothedHeading += 360 }
            }
            self.heading = self.smoothedHeading
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
