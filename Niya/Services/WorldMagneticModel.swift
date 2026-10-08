import Foundation

/// NOAA World Magnetic Model (WMM2025): magnetic declination anywhere on Earth, offline.
///
/// Core Location only reports `trueHeading` while location updates are running, and never
/// for a manually chosen location, so the compass corrects `magneticHeading` itself.
/// Coefficients are WMM2025 (epoch 2025.0, valid through 2029, public domain) from
/// https://www.ncei.noaa.gov/products/world-magnetic-model (WMM.COF). Replace them with the
/// next release (WMM2030, published late 2029); `WorldMagneticModelTests` checks NOAA's
/// published test values, so update those alongside.
enum WorldMagneticModel {
    static let epoch = 2025.0
    private static let maxDegree = 12
    private static let referenceRadiusKm = 6371.2
    private static let wgs84SemiMajorKm = 6378.137
    private static let wgs84Flattening = 1 / 298.257223563

    /// Degrees east of true north that magnetic north lies; true = magnetic + declination.
    static func declination(latitude: Double, longitude: Double, altitudeKm: Double = 0, date: Date) -> Double {
        declination(latitude: latitude, longitude: longitude, altitudeKm: altitudeKm, decimalYear: decimalYear(date))
    }

    static func declination(latitude: Double, longitude: Double, altitudeKm: Double = 0, decimalYear: Double) -> Double {
        let lat = min(max(latitude, -89.999), 89.999) * .pi / 180
        let lon = longitude * .pi / 180

        // Geodetic (WGS84) to geocentric spherical coordinates.
        let e2 = wgs84Flattening * (2 - wgs84Flattening)
        let primeVertical = wgs84SemiMajorKm / (1 - e2 * sin(lat) * sin(lat)).squareRoot()
        let p = (primeVertical + altitudeKm) * cos(lat)
        let z = (primeVertical * (1 - e2) + altitudeKm) * sin(lat)
        let r = (p * p + z * z).squareRoot()
        let geocentricLat = asin(z / r)
        let x = sin(geocentricLat), s = cos(geocentricLat)

        // Schmidt semi-normalized associated Legendre functions and their latitude derivatives.
        let n1 = maxDegree + 1
        var pnm = [Double](repeating: 0, count: n1 * n1)
        var dpnm = [Double](repeating: 0, count: n1 * n1)
        pnm[0] = 1
        for n in 1...maxDegree {
            for m in 0...n {
                let i = n * n1 + m
                if m == n {
                    if n == 1 {
                        pnm[i] = s; dpnm[i] = -x
                    } else {
                        let k = (Double(2 * n - 1) / Double(2 * n)).squareRoot()
                        let prev = (n - 1) * n1 + (n - 1)
                        pnm[i] = k * s * pnm[prev]
                        dpnm[i] = k * (s * dpnm[prev] - x * pnm[prev])
                    }
                } else {
                    let prev = (n - 1) * n1 + m
                    var p2 = 0.0, d2 = 0.0, k2 = 0.0
                    if n - 2 >= m {
                        let prev2 = (n - 2) * n1 + m
                        p2 = pnm[prev2]; d2 = dpnm[prev2]
                        k2 = Double((n - 1 + m) * (n - 1 - m)).squareRoot()
                    }
                    let denominator = Double((n + m) * (n - m)).squareRoot()
                    pnm[i] = (Double(2 * n - 1) * x * pnm[prev] - k2 * p2) / denominator
                    dpnm[i] = (Double(2 * n - 1) * (s * pnm[prev] + x * dpnm[prev]) - k2 * d2) / denominator
                }
            }
        }

        let dt = decimalYear - epoch
        var north = 0.0, east = 0.0, down = 0.0
        for c in coefficients {
            let (n, m) = (c.n, c.m)
            let g = c.g + c.gDot * dt, h = c.h + c.hDot * dt
            let ratio = pow(referenceRadiusKm / r, Double(n + 2))
            let cosM = cos(Double(m) * lon), sinM = sin(Double(m) * lon)
            let i = n * n1 + m
            north -= ratio * (g * cosM + h * sinM) * dpnm[i]
            east += ratio * Double(m) * (g * sinM - h * cosM) * pnm[i] / s
            down -= Double(n + 1) * ratio * (g * cosM + h * sinM) * pnm[i]
        }
        // Rotate the north component back to the geodetic frame.
        let psi = geocentricLat - lat
        let geodeticNorth = north * cos(psi) - down * sin(psi)
        return atan2(east, geodeticNorth) * 180 / .pi
    }

    static func decimalYear(_ date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let year = calendar.component(.year, from: date)
        let start = calendar.date(from: DateComponents(year: year))!
        let end = calendar.date(from: DateComponents(year: year + 1))!
        return Double(year) + date.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    private struct Coefficient {
        let n: Int, m: Int, g: Double, h: Double, gDot: Double, hDot: Double
    }

    private static let coefficients: [Coefficient] = rows.map {
        Coefficient(n: $0.0, m: $0.1, g: $0.2, h: $0.3, gDot: $0.4, hDot: $0.5)
    }

    // n, m, g (nT), h (nT), dg/dt (nT/yr), dh/dt (nT/yr) — verbatim from WMM2025 WMM.COF.
    private static let rows: [(Int, Int, Double, Double, Double, Double)] = [
        (1, 0, -29351.8, 0.0, 12.0, 0.0),
        (1, 1, -1410.8, 4545.4, 9.7, -21.5),
        (2, 0, -2556.6, 0.0, -11.6, 0.0),
        (2, 1, 2951.1, -3133.6, -5.2, -27.7),
        (2, 2, 1649.3, -815.1, -8.0, -12.1),
        (3, 0, 1361.0, 0.0, -1.3, 0.0),
        (3, 1, -2404.1, -56.6, -4.2, 4.0),
        (3, 2, 1243.8, 237.5, 0.4, -0.3),
        (3, 3, 453.6, -549.5, -15.6, -4.1),
        (4, 0, 895.0, 0.0, -1.6, 0.0),
        (4, 1, 799.5, 278.6, -2.4, -1.1),
        (4, 2, 55.7, -133.9, -6.0, 4.1),
        (4, 3, -281.1, 212.0, 5.6, 1.6),
        (4, 4, 12.1, -375.6, -7.0, -4.4),
        (5, 0, -233.2, 0.0, 0.6, 0.0),
        (5, 1, 368.9, 45.4, 1.4, -0.5),
        (5, 2, 187.2, 220.2, 0.0, 2.2),
        (5, 3, -138.7, -122.9, 0.6, 0.4),
        (5, 4, -142.0, 43.0, 2.2, 1.7),
        (5, 5, 20.9, 106.1, 0.9, 1.9),
        (6, 0, 64.4, 0.0, -0.2, 0.0),
        (6, 1, 63.8, -18.4, -0.4, 0.3),
        (6, 2, 76.9, 16.8, 0.9, -1.6),
        (6, 3, -115.7, 48.8, 1.2, -0.4),
        (6, 4, -40.9, -59.8, -0.9, 0.9),
        (6, 5, 14.9, 10.9, 0.3, 0.7),
        (6, 6, -60.7, 72.7, 0.9, 0.9),
        (7, 0, 79.5, 0.0, -0.0, 0.0),
        (7, 1, -77.0, -48.9, -0.1, 0.6),
        (7, 2, -8.8, -14.4, -0.1, 0.5),
        (7, 3, 59.3, -1.0, 0.5, -0.8),
        (7, 4, 15.8, 23.4, -0.1, 0.0),
        (7, 5, 2.5, -7.4, -0.8, -1.0),
        (7, 6, -11.1, -25.1, -0.8, 0.6),
        (7, 7, 14.2, -2.3, 0.8, -0.2),
        (8, 0, 23.2, 0.0, -0.1, 0.0),
        (8, 1, 10.8, 7.1, 0.2, -0.2),
        (8, 2, -17.5, -12.6, 0.0, 0.5),
        (8, 3, 2.0, 11.4, 0.5, -0.4),
        (8, 4, -21.7, -9.7, -0.1, 0.4),
        (8, 5, 16.9, 12.7, 0.3, -0.5),
        (8, 6, 15.0, 0.7, 0.2, -0.6),
        (8, 7, -16.8, -5.2, -0.0, 0.3),
        (8, 8, 0.9, 3.9, 0.2, 0.2),
        (9, 0, 4.6, 0.0, -0.0, 0.0),
        (9, 1, 7.8, -24.8, -0.1, -0.3),
        (9, 2, 3.0, 12.2, 0.1, 0.3),
        (9, 3, -0.2, 8.3, 0.3, -0.3),
        (9, 4, -2.5, -3.3, -0.3, 0.3),
        (9, 5, -13.1, -5.2, 0.0, 0.2),
        (9, 6, 2.4, 7.2, 0.3, -0.1),
        (9, 7, 8.6, -0.6, -0.1, -0.2),
        (9, 8, -8.7, 0.8, 0.1, 0.4),
        (9, 9, -12.9, 10.0, -0.1, 0.1),
        (10, 0, -1.3, 0.0, 0.1, 0.0),
        (10, 1, -6.4, 3.3, 0.0, 0.0),
        (10, 2, 0.2, 0.0, 0.1, -0.0),
        (10, 3, 2.0, 2.4, 0.1, -0.2),
        (10, 4, -1.0, 5.3, -0.0, 0.1),
        (10, 5, -0.6, -9.1, -0.3, -0.1),
        (10, 6, -0.9, 0.4, 0.0, 0.1),
        (10, 7, 1.5, -4.2, -0.1, 0.0),
        (10, 8, 0.9, -3.8, -0.1, -0.1),
        (10, 9, -2.7, 0.9, -0.0, 0.2),
        (10, 10, -3.9, -9.1, -0.0, -0.0),
        (11, 0, 2.9, 0.0, 0.0, 0.0),
        (11, 1, -1.5, 0.0, -0.0, -0.0),
        (11, 2, -2.5, 2.9, 0.0, 0.1),
        (11, 3, 2.4, -0.6, 0.0, -0.0),
        (11, 4, -0.6, 0.2, 0.0, 0.1),
        (11, 5, -0.1, 0.5, -0.1, -0.0),
        (11, 6, -0.6, -0.3, 0.0, -0.0),
        (11, 7, -0.1, -1.2, -0.0, 0.1),
        (11, 8, 1.1, -1.7, -0.1, -0.0),
        (11, 9, -1.0, -2.9, -0.1, 0.0),
        (11, 10, -0.2, -1.8, -0.1, 0.0),
        (11, 11, 2.6, -2.3, -0.1, 0.0),
        (12, 0, -2.0, 0.0, 0.0, 0.0),
        (12, 1, -0.2, -1.3, 0.0, -0.0),
        (12, 2, 0.3, 0.7, -0.0, 0.0),
        (12, 3, 1.2, 1.0, -0.0, -0.1),
        (12, 4, -1.3, -1.4, -0.0, 0.1),
        (12, 5, 0.6, -0.0, -0.0, -0.0),
        (12, 6, 0.6, 0.6, 0.1, -0.0),
        (12, 7, 0.5, -0.1, -0.0, -0.0),
        (12, 8, -0.1, 0.8, 0.0, 0.0),
        (12, 9, -0.4, 0.1, 0.0, -0.0),
        (12, 10, -0.2, -1.0, -0.1, -0.0),
        (12, 11, -1.3, 0.1, -0.0, 0.0),
        (12, 12, -0.7, 0.2, -0.1, -0.1)
    ]
}
