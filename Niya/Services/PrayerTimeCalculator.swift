import Foundation

struct PrayerTimeCalculator: Sendable {

    private init() {}

    // MARK: - Public API

    static func calculate(
        date: Date,
        location: UserLocation,
        method: CalculationMethod,
        asrFactor: Int = 1
    ) -> DailyPrayerTimes {
        let tz = location.timeZone
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: tz, from: date)
        let year = comps.year!
        let month = comps.month!
        let day = comps.day!

        let jd = julianDay(year: year, month: month, day: day)
        let lat = location.latitude
        let lng = location.longitude
        let tzOffset = Double(tz.secondsFromGMT(for: date)) / 3600.0

        var estimates: [Double] = [5, 6, 12, 13, 18, 18, 18]

        // Two iterations for convergence
        for _ in 0..<2 {
            let fajrPos = sunPosition(jd: jd + (estimates[0] / 24.0 - tzOffset / 24.0))
            let sunrisePos = sunPosition(jd: jd + (estimates[1] / 24.0 - tzOffset / 24.0))
            let dhuhrPos = sunPosition(jd: jd + (estimates[2] / 24.0 - tzOffset / 24.0))
            let asrPos = sunPosition(jd: jd + (estimates[3] / 24.0 - tzOffset / 24.0))
            let sunsetPos = sunPosition(jd: jd + (estimates[4] / 24.0 - tzOffset / 24.0))
            let ishaPos = sunPosition(jd: jd + (estimates[6] / 24.0 - tzOffset / 24.0))

            let transit = 12.0 + tzOffset - lng / 15.0 - dhuhrPos.eqTime / 60.0

            let sunriseHA = hourAngle(latitude: lat, declination: sunrisePos.declination, angle: 0.8333)
            let sunrise = transit - sunriseHA / 15.0
            let sunsetHA = hourAngle(latitude: lat, declination: sunsetPos.declination, angle: 0.8333)
            let sunset = transit + sunsetHA / 15.0

            let fajrHA = hourAngleSafe(latitude: lat, declination: fajrPos.declination, angle: method.fajrAngle)
            let fajr: Double
            if let ha = fajrHA {
                fajr = transit - ha / 15.0
            } else {
                let night = sunrise + 24 - sunset
                fajr = sunrise - night / 7.0
            }

            let asrAngle = asrElevation(factor: Double(asrFactor), declination: asrPos.declination, latitude: lat)
            let asrHA = hourAngle(latitude: lat, declination: asrPos.declination, angle: -asrAngle)
            let asr = transit + asrHA / 15.0

            let isha: Double
            if let ishaMinutes = method.ishaMinutesAfterMaghrib {
                isha = sunset + ishaMinutes / 60.0
            } else if let ishaAngleDeg = method.ishaAngle {
                let ishaHA = hourAngleSafe(latitude: lat, declination: ishaPos.declination, angle: ishaAngleDeg)
                if let ha = ishaHA {
                    isha = transit + ha / 15.0
                } else {
                    let night = sunrise + 24 - sunset
                    isha = sunset + night / 7.0
                }
            } else {
                isha = sunset + 1.5
            }

            estimates = [fajr, sunrise, transit, asr, sunset, sunset, isha]
        }

        func makeDate(hours: Double) -> Date {
            let totalSeconds = hours * 3600
            let h = Int(totalSeconds) / 3600
            let m = (Int(totalSeconds) % 3600) / 60
            let s = Int(totalSeconds) % 60
            var dc = DateComponents()
            dc.year = year
            dc.month = month
            dc.day = day
            dc.hour = h
            dc.minute = m
            dc.second = s
            dc.timeZone = tz
            return cal.date(from: dc) ?? date
        }

        let times = [
            PrayerTime(prayer: .fajr, time: makeDate(hours: estimates[0])),
            PrayerTime(prayer: .sunrise, time: makeDate(hours: estimates[1])),
            PrayerTime(prayer: .dhuhr, time: makeDate(hours: estimates[2])),
            PrayerTime(prayer: .asr, time: makeDate(hours: estimates[3])),
            PrayerTime(prayer: .maghrib, time: makeDate(hours: estimates[4])),
            PrayerTime(prayer: .isha, time: makeDate(hours: estimates[6])),
        ]

        return DailyPrayerTimes(date: date, times: times, location: location, method: method)
    }

    static func qiblahBearing(from location: UserLocation) -> Double {
        let kaabaLat = 21.4225 * .pi / 180
        let kaabaLon = 39.8262 * .pi / 180
        let userLat = location.latitude * .pi / 180
        let userLon = location.longitude * .pi / 180

        let dLon = kaabaLon - userLon
        let y = sin(dLon) * cos(kaabaLat)
        let x = cos(userLat) * sin(kaabaLat) - sin(userLat) * cos(kaabaLat) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - NOAA Solar Position (higher accuracy)

    struct SunPos {
        let declination: Double // degrees
        let eqTime: Double      // minutes
    }

    static func sunPosition(jd: Double) -> SunPos {
        let t = (jd - 2451545.0) / 36525.0 // Julian century

        // Geometric mean longitude (degrees)
        let l0 = fixAngle(280.46646 + 36000.76983 * t + 0.0003032 * t * t)
        // Geometric mean anomaly (degrees)
        let m = fixAngle(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
        // Eccentricity of Earth's orbit
        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
        // Sun equation of center (degrees)
        let mRad = m * .pi / 180
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(mRad)
            + (0.019993 - 0.000101 * t) * sin(2 * mRad)
            + 0.000289 * sin(3 * mRad)
        // Sun true longitude
        let sunTL = l0 + c
        // Sun apparent longitude (corrected for nutation + aberration)
        let omega = 125.04 - 1934.136 * t
        let omegaRad = omega * .pi / 180
        let sunAL = sunTL - 0.00569 - 0.00478 * sin(omegaRad)
        // Mean obliquity of ecliptic
        let obliquity0 = 23.0 + (26.0 + (21.448 - 46.815 * t - 0.00059 * t * t + 0.001813 * t * t * t) / 60.0) / 60.0
        // Corrected obliquity
        let obliquity = obliquity0 + 0.00256 * cos(omegaRad)

        let oblRad = obliquity * .pi / 180
        let sunALRad = sunAL * .pi / 180

        // Sun declination
        let sinDecl = sin(oblRad) * sin(sunALRad)
        let declination = asin(sinDecl) * 180 / .pi

        // Equation of time (minutes)
        let y2 = tan(oblRad / 2) * tan(oblRad / 2)
        let l0Rad = l0 * .pi / 180
        let eqTime = 4 * (180 / .pi) * (
            y2 * sin(2 * l0Rad)
            - 2 * e * sin(mRad)
            + 4 * e * y2 * sin(mRad) * cos(2 * l0Rad)
            - 0.5 * y2 * y2 * sin(4 * l0Rad)
            - 1.25 * e * e * sin(2 * mRad)
        )

        return SunPos(declination: declination, eqTime: eqTime)
    }

    static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year)
        var m = Double(month)
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    // MARK: - Hour Angle

    static func hourAngle(latitude: Double, declination: Double, angle: Double) -> Double {
        let latRad = latitude * .pi / 180
        let declRad = declination * .pi / 180
        let angleRad = -angle * .pi / 180
        let cosHA = (sin(angleRad) - sin(latRad) * sin(declRad)) / (cos(latRad) * cos(declRad))
        let clamped = max(-1, min(1, cosHA))
        return acos(clamped) * 180 / .pi
    }

    private static func hourAngleSafe(latitude: Double, declination: Double, angle: Double) -> Double? {
        let latRad = latitude * .pi / 180
        let declRad = declination * .pi / 180
        let angleRad = -angle * .pi / 180
        let cosHA = (sin(angleRad) - sin(latRad) * sin(declRad)) / (cos(latRad) * cos(declRad))
        if cosHA < -1 || cosHA > 1 { return nil }
        return acos(cosHA) * 180 / .pi
    }

    private static func asrElevation(factor: Double, declination: Double, latitude: Double) -> Double {
        let declRad = declination * .pi / 180
        let latRad = latitude * .pi / 180
        let d = abs(declRad - latRad)
        let cotAlt = factor + tan(d)
        let alt = atan(1.0 / cotAlt)
        return alt * 180 / .pi
    }

    private static func fixAngle(_ a: Double) -> Double {
        var result = a.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }
}
