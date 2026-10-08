import Foundation

/// Turns Core Location's raw magnetic headings into the true-north heading the Qiblah
/// dial shows: invalid samples are dropped, declination is applied, and jitter is
/// smoothed without lagging real turns.
struct CompassHeading: Equatable {
    /// Unwrapped true heading in degrees. Rotating the dial by its negation always takes
    /// the short way across north (359° → 1° is +2°, never -358°).
    private(set) var continuousHeading: Double = 0
    /// Core Location's uncertainty in degrees; negative while uncalibrated or before the
    /// first sample.
    private(set) var accuracy: Double = -1
    private var lastSampleTime: Date?

    /// A gap this long (backgrounding, the sheet reopening, a calibration pause) means the
    /// device may have turned arbitrarily, so the next sample is shown at once.
    static let resumeGap: TimeInterval = 1

    /// True heading in [0, 360).
    var heading: Double { Self.normalized(continuousHeading) }

    var quality: CompassAccuracy { CompassAccuracy(headingAccuracy: accuracy) }

    /// - Parameters:
    ///   - magneticHeading: `CLHeading.magneticHeading`, degrees from magnetic north.
    ///   - accuracy: `CLHeading.headingAccuracy`; negative means the sample is invalid.
    ///   - declination: degrees east of true north that magnetic north lies.
    mutating func ingest(magneticHeading: Double, accuracy: Double, declination: Double, at time: Date) {
        self.accuracy = accuracy
        // Apple: a negative accuracy means the heading is invalid, so hold the dial.
        guard accuracy >= 0, magneticHeading >= 0 else { return }

        let target = Self.normalized(magneticHeading + declination)
        let delta = Self.shortestDelta(from: heading, to: target)
        defer { lastSampleTime = time }

        guard let last = lastSampleTime, time.timeIntervalSince(last) <= Self.resumeGap else {
            continuousHeading += delta
            return
        }
        let dt = min(max(time.timeIntervalSince(last), 0), 0.25)
        let alpha = 1 - exp(-dt / Self.smoothingTimeConstant(forDelta: delta))
        continuousHeading += alpha * delta
    }

    /// Heading updates stopped; the next sample snaps instead of easing in from stale state.
    /// The last accuracy is kept so reopening the compass does not flash a calibration hint.
    mutating func suspend() {
        lastSampleTime = nil
    }

    /// Adaptive smoothing: ±1° sensor noise is averaged over ~0.1 s (damped ~80%), while
    /// a real turn of tens of degrees is followed within one or two samples.
    static func smoothingTimeConstant(forDelta delta: Double) -> TimeInterval {
        0.15 / (1 + abs(delta) / 3)
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    static func shortestDelta(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
}

enum CompassAccuracy: Equatable {
    case good, reduced, poor, calibrating

    init(headingAccuracy: Double) {
        switch headingAccuracy {
        case ..<0: self = .calibrating
        case ...15: self = .good
        case ...25: self = .reduced
        default: self = .poor
        }
    }
}

enum QiblahFormatting {
    /// "59° NE": rounded to the nearest degree (359.6° reads 0° N, not 359° NNW).
    static func bearingLabel(_ degrees: Double) -> String {
        let rounded = Int(CompassHeading.normalized(degrees).rounded()) % 360
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(rounded) + 11.25) / 22.5) % 16
        return "\(rounded)° \(directions[index])"
    }
}

/// Whether the top of the device faces the Qiblah. Hysteresis (enter within 3°, leave
/// beyond 5°) keeps the highlight and haptic from chattering at the edge, and alignment is
/// only claimed while Core Location reports good accuracy.
enum QiblahAlignment {
    static let enterDegrees = 3.0
    static let exitDegrees = 5.0

    /// Degrees to turn to face the Qiblah; positive is clockwise (to the right).
    static func turn(heading: Double, bearing: Double) -> Double {
        CompassHeading.shortestDelta(from: heading, to: bearing)
    }

    static func isAligned(heading: Double, bearing: Double, accuracy: CompassAccuracy, wasAligned: Bool) -> Bool {
        guard accuracy == .good else { return false }
        return abs(turn(heading: heading, bearing: bearing)) <= (wasAligned ? exitDegrees : enterDegrees)
    }

    static func spokenGuidance(heading: Double, bearing: Double, aligned: Bool) -> String {
        if aligned { return "Facing the Qiblah" }
        let turn = turn(heading: heading, bearing: bearing)
        let degrees = Int(abs(turn).rounded())
        return turn > 0 ? "Turn right \(degrees) degrees" : "Turn left \(degrees) degrees"
    }
}
