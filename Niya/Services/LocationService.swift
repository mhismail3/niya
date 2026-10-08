import Foundation
import CoreLocation
import MapKit
import SwiftUI

@Observable
@MainActor
final class LocationService: NSObject {
    var currentLocation: UserLocation?
    /// True-north heading for the Qiblah dial, corrected and smoothed from raw samples.
    private(set) var compass = CompassHeading()
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

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var isUpdatingHeading = false
    @ObservationIgnored private var lastGeocodeDate: Date?
    @ObservationIgnored private var declinationCache: (latitude: Double, longitude: Double, value: Double)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        // Every sample: CompassHeading's time-based smoothing needs a steady stream, and a
        // 1° filter stops delivery while the device is still, freezing the dial short of
        // where it is actually pointing.
        manager.headingFilter = kCLHeadingFilterNone
        authorizationStatus = manager.authorizationStatus
        completer.delegate = self
        completer.resultTypes = .address
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
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
        updateHeadingOrientation()
        guard CLLocationManager.headingAvailable(), !isUpdatingHeading else { return }
        isUpdatingHeading = true
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        guard isUpdatingHeading else { return }
        isUpdatingHeading = false
        compass.suspend()
        manager.stopUpdatingHeading()
    }

    /// Headings are measured from the top of the interface, which follows its rotation.
    private func updateHeadingOrientation() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        else { return }
        let orientation = Self.headingOrientation(for: scene.interfaceOrientation)
        if manager.headingOrientation != orientation {
            manager.headingOrientation = orientation
        }
    }

    /// `CLDeviceOrientation` names the device's physical orientation, and an interface in
    /// landscape-left has the device in landscape-right (UIOrientation.h), so the landscape
    /// cases swap. Mapping them name-for-name points the dial 180° the wrong way.
    nonisolated static func headingOrientation(for interface: UIInterfaceOrientation) -> CLDeviceOrientation {
        switch interface {
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        default: .portrait
        }
    }

    /// Declination at the location the Qiblah bearing is computed for (manual or GPS),
    /// recomputed only when that location changes.
    private func declination() -> Double {
        guard let location = effectiveLocation else { return 0 }
        if let cache = declinationCache,
           cache.latitude == location.latitude, cache.longitude == location.longitude {
            return cache.value
        }
        let value = WorldMagneticModel.declination(
            latitude: location.latitude, longitude: location.longitude, date: Date()
        )
        declinationCache = (location.latitude, location.longitude, value)
        return value
    }

    /// Fresh and good enough for prayer times, which shift by well under a minute per
    /// 10 km (approximate-location users report 3–9 km accuracy).
    nonisolated static func isUsableFix(_ location: CLLocation, now: Date) -> Bool {
        location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= 10_000
            && abs(location.timestamp.timeIntervalSince(now)) <= 120
    }

    nonisolated static func requiresPrayerRecalculation(from old: UserLocation?, to new: UserLocation) -> Bool {
        guard let old else { return true }
        guard old.timezoneIdentifier == new.timezoneIdentifier else { return true }
        let a = CLLocation(latitude: old.latitude, longitude: old.longitude)
        let b = CLLocation(latitude: new.latitude, longitude: new.longitude)
        return a.distance(from: b) > 1_000
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
        // Updates stop after the first accepted fix, so skip the cached/stale fix CoreLocation
        // often delivers first and keep listening for a current one.
        guard let loc = locations.last(where: { Self.isUsableFix($0, now: Date()) }) else { return }
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
            let updated = UserLocation(
                latitude: coord.latitude,
                longitude: coord.longitude,
                name: name,
                timezoneIdentifier: tzId
            )
            self.currentLocation = updated
            self.manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Delegate callbacks arrive on the thread that created the manager (main, in init).
        // Handling them synchronously keeps samples in order with no extra hop of latency.
        // `trueHeading` is ignored: Core Location only provides it while location updates
        // run, which stop after the first fix and never run for a manual location, so the
        // dial used to jump by the local declination (e.g. 13° in California) mid-use.
        let magnetic = newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        let timestamp = newHeading.timestamp
        guard Thread.isMainThread else {
            Task { @MainActor in self.ingestHeading(magnetic: magnetic, accuracy: accuracy, at: timestamp) }
            return
        }
        MainActor.assumeIsolated { self.ingestHeading(magnetic: magnetic, accuracy: accuracy, at: timestamp) }
    }

    private func ingestHeading(magnetic: Double, accuracy: Double, at timestamp: Date) {
        guard isUpdatingHeading else { return }
        updateHeadingOrientation()
        compass.ingest(magneticHeading: magnetic, accuracy: accuracy, declination: declination(), at: timestamp)
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
