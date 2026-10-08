import CoreLocation
import Foundation
import Testing
import UIKit
@testable import Niya

@Suite("World Magnetic Model")
struct WorldMagneticModelTests {
    /// Decimal year, altitude (km), latitude, longitude, declination — a spread of NOAA's
    /// published WMM2025 test values (WMM2025_TestValues.txt), rounded there to 0.01°.
    private static let noaaReference: [(Double, Double, Double, Double, Double)] = [
        (2025.0, 28.0, 89.0, -121.0, -99.77),
        (2025.0, 94.0, -29.0, -110.0, 15.74),
        (2025.5, 8.0, -52.0, -75.0, 14.91),
        (2026.0, 46.0, -24.0, -122.0, 14.01),
        (2026.0, 34.0, -19.0, 43.0, -14.98),
        (2026.5, 12.0, 33.0, -145.0, 11.96),
        (2027.0, 44.0, 22.0, 174.0, 6.46),
        (2027.0, 67.0, -47.0, -32.0, -13.52),
        (2027.5, 96.0, -46.0, -85.0, 17.93),
        (2028.0, 86.0, -85.0, -79.0, 41.09),
        (2028.5, 28.0, 54.0, -120.0, 15.43),
        (2028.5, 59.0, 32.0, 163.0, 0.15),
        (2029.0, 57.0, 34.0, -13.0, -1.89),
        (2029.5, 93.0, -2.0, 158.0, 7.09),
        (2029.5, 33.0, 17.0, 5.0, 0.89),
    ]

    @Test func matchesNOAATestValues() {
        for (year, altitude, latitude, longitude, expected) in Self.noaaReference {
            let value = WorldMagneticModel.declination(
                latitude: latitude, longitude: longitude, altitudeKm: altitude, decimalYear: year
            )
            #expect(abs(value - expected) < 0.01, "\(latitude), \(longitude) @ \(year): \(value) vs \(expected)")
        }
    }

    @Test func decimalYearIsUTCFraction() {
        let midYear = ISO8601DateFormatter().date(from: "2026-07-02T12:00:00Z")!
        #expect(abs(WorldMagneticModel.decimalYear(midYear) - 2026.5) < 0.001)
    }
}

@Suite("Compass heading")
struct CompassHeadingTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    /// Feeds a steady 30 Hz stream of one reading for the given duration.
    private func hold(_ compass: inout CompassHeading, magnetic: Double, declination: Double = 0,
                      from start: TimeInterval, seconds: TimeInterval) {
        var t = start
        while t <= start + seconds {
            compass.ingest(magneticHeading: magnetic, accuracy: 5, declination: declination, at: t0 + t)
            t += 1.0 / 30
        }
    }

    @Test func firstSampleIsShownImmediatelyAsTrueHeading() {
        var compass = CompassHeading()
        // Cupertino: magnetic north lies ~12.7° east of true north.
        compass.ingest(magneticHeading: 100, accuracy: 5, declination: 12.7, at: t0)
        #expect(abs(compass.heading - 112.7) < 1e-9)
    }

    @Test func invalidSamplesHoldTheDialAndReportCalibrating() {
        var compass = CompassHeading()
        compass.ingest(magneticHeading: 40, accuracy: 5, declination: 0, at: t0)
        compass.ingest(magneticHeading: 220, accuracy: -1, declination: 0, at: t0 + 0.1)
        #expect(compass.heading == 40)
        #expect(compass.quality == .calibrating)
    }

    @Test func settlesOnARealTurnQuickly() {
        var compass = CompassHeading()
        hold(&compass, magnetic: 10, from: 0, seconds: 0.5)
        hold(&compass, magnetic: 100, from: 0.5 + 1.0 / 30, seconds: 0.3)
        #expect(abs(compass.heading - 100) < 0.5, "\(compass.heading)")
    }

    @Test func smallStepIsReachedWhileTheDeviceIsStill() {
        // Smoothing is time-based, so a steady sample stream converges fully on a small step.
        var compass = CompassHeading()
        hold(&compass, magnetic: 50, from: 0, seconds: 0.5)
        hold(&compass, magnetic: 53, from: 0.5 + 1.0 / 30, seconds: 1.5)
        #expect(abs(compass.heading - 53) < 0.1, "\(compass.heading)")
    }

    @Test func sensorJitterIsDamped() {
        var compass = CompassHeading()
        compass.ingest(magneticHeading: 90, accuracy: 5, declination: 0, at: t0)
        var low = Double.infinity, high = -Double.infinity
        for i in 1...90 {
            let noisy = 90 + (i.isMultiple(of: 2) ? 1.0 : -1.0)
            compass.ingest(magneticHeading: noisy, accuracy: 5, declination: 0, at: t0 + Double(i) / 30)
            low = min(low, compass.heading); high = max(high, compass.heading)
        }
        #expect(high - low < 0.5, "±1° noise swung the dial \(high - low)°")
    }

    @Test func crossingNorthTakesTheShortWay() {
        var compass = CompassHeading()
        hold(&compass, magnetic: 358, from: 0, seconds: 0.2)
        let before = compass.continuousHeading
        hold(&compass, magnetic: 2, from: 0.2 + 1.0 / 30, seconds: 1)
        #expect(abs(compass.continuousHeading - before - 4) < 0.1, "\(compass.continuousHeading - before)")
        #expect(abs(compass.heading - 2) < 0.1)
    }

    @Test func resumingAfterAPauseSnapsTheShortWay() {
        var compass = CompassHeading()
        hold(&compass, magnetic: 350, from: 0, seconds: 0.2)
        compass.suspend()
        let before = compass.continuousHeading
        compass.ingest(magneticHeading: 20, accuracy: 5, declination: 0, at: t0 + 30)
        #expect(abs(compass.heading - 20) < 1e-9)
        #expect(abs(compass.continuousHeading - before - 30) < 1e-6)
    }

    @Test func accuracyBands() {
        #expect(CompassAccuracy(headingAccuracy: -1) == .calibrating)
        #expect(CompassAccuracy(headingAccuracy: 15) == .good)
        #expect(CompassAccuracy(headingAccuracy: 20) == .reduced)
        #expect(CompassAccuracy(headingAccuracy: 30) == .poor)
    }

    @Test func headingOrientationFollowsThePhysicalDevice() {
        // An interface in landscape-left has the device in landscape-right (UIOrientation.h).
        #expect(LocationService.headingOrientation(for: .landscapeLeft) == .landscapeRight)
        #expect(LocationService.headingOrientation(for: .landscapeRight) == .landscapeLeft)
        #expect(LocationService.headingOrientation(for: .portraitUpsideDown) == .portraitUpsideDown)
        #expect(LocationService.headingOrientation(for: .portrait) == .portrait)
        #expect(LocationService.headingOrientation(for: .unknown) == .portrait)
    }

    @Test func bearingLabelRoundsToTheNearestDegree() {
        #expect(QiblahFormatting.bearingLabel(58.9) == "59° ENE")
        #expect(QiblahFormatting.bearingLabel(359.6) == "0° N")
        #expect(QiblahFormatting.bearingLabel(118.99) == "119° ESE")
    }
}
