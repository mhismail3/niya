import SwiftUI

struct QiblahCompassView: View {
    let bearing: Double
    let heading: Double
    let headingAvailable: Bool
    let headingAccuracy: Double
    var compassSize: CGFloat = 260

    @State private var continuousRotation: Double = 0
    @State private var lastHeading: Double?

    private var arrowSize: CGFloat {
        compassSize * 0.108
    }

    private var kaabaSize: CGFloat {
        compassSize * 0.09
    }

    private var accuracyState: AccuracyState {
        if headingAccuracy < 0 { return .calibrating }
        if headingAccuracy > 25 { return .poor }
        if headingAccuracy > 15 { return .fair }
        return .good
    }

    private var ringColor: Color {
        switch accuracyState {
        case .good: return Color.niyaSecondary.opacity(0.3)
        case .fair: return Color.niyaGold.opacity(0.5)
        case .poor, .calibrating: return Color.red.opacity(0.4)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if !headingAvailable {
                staticCompass
            } else {
                compassDial
            }

            if accuracyState != .good && headingAvailable {
                accuracyBanner
            }

            bearingText
        }
        .onChange(of: heading) { oldVal, newVal in
            let prev = lastHeading ?? oldVal
            var delta = newVal - prev
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }

            // Dampen large jumps when accuracy is poor — likely interference
            if accuracyState == .poor || accuracyState == .calibrating {
                if abs(delta) > 15 {
                    lastHeading = newVal
                    return
                }
            }

            continuousRotation += delta
            lastHeading = newVal
        }
    }

    private var compassDial: some View {
        ZStack {
            Circle()
                .stroke(ringColor, lineWidth: 2)
                .frame(width: compassSize, height: compassSize)

            ForEach(0..<36, id: \.self) { i in
                let angle = Double(i) * 10
                let isMajor = i % 9 == 0
                Rectangle()
                    .fill(isMajor ? Color.niyaText : Color.niyaSecondary.opacity(0.4))
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 16 : 8)
                    .offset(y: -compassSize / 2 + (isMajor ? 8 : 4))
                    .rotationEffect(.degrees(angle))
            }

            ForEach(cardinalDirections, id: \.label) { dir in
                Text(dir.label)
                    .font(.system(size: compassSize * 0.07, weight: .semibold, design: .serif))
                    .foregroundStyle(dir.label == "N" ? Color.red : Color.niyaText)
                    .offset(y: -compassSize / 2 + 30)
                    .rotationEffect(.degrees(dir.angle))
            }

            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: arrowSize, weight: .bold))
                    .foregroundStyle(Color.niyaTeal)
                Image(systemName: "building.columns")
                    .font(.system(size: kaabaSize))
                    .foregroundStyle(Color.niyaTeal)
            }
            .rotationEffect(.degrees(bearing))
        }
        .rotationEffect(.degrees(-continuousRotation))
        .animation(.easeInOut(duration: 0.3), value: continuousRotation)
    }

    private var staticCompass: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.niyaSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: compassSize, height: compassSize)

                Image(systemName: "building.columns")
                    .font(.system(size: compassSize * 0.115))
                    .foregroundStyle(Color.niyaTeal)

                VStack(spacing: 0) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: compassSize * 0.085, weight: .bold))
                        .foregroundStyle(Color.niyaTeal)
                }
                .offset(y: -compassSize / 2 + 30)
                .rotationEffect(.degrees(bearing))
            }

            Text("Compass not available on this device")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
        }
    }

    private var accuracyBanner: some View {
        let color: Color = accuracyState == .fair ? .niyaGold : .red
        return HStack(spacing: 6) {
            Image(systemName: accuracyState == .fair ? "exclamationmark.triangle" : "figure.wave")
                .font(.niyaCaption)
            Text(accuracyState.message)
                .font(.niyaCaption2)
        }
        .foregroundStyle(color)
    }

    private var bearingText: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.columns")
                .foregroundStyle(Color.niyaTeal)
            Text("\(Int(bearing))° \(cardinalDirection(for: bearing))")
                .font(.niyaBody)
                .foregroundStyle(Color.niyaText)
        }
    }

    private func cardinalDirection(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }

    private var cardinalDirections: [(label: String, angle: Double)] {
        [("N", 0), ("E", 90), ("S", 180), ("W", 270)]
    }
}

private enum AccuracyState {
    case good
    case fair
    case poor
    case calibrating

    var message: String {
        switch self {
        case .good: return ""
        case .fair: return "Compass accuracy is reduced"
        case .poor: return "Low accuracy — move away from metal objects"
        case .calibrating: return "Move your device in a figure-8 to calibrate"
        }
    }
}
