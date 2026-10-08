import SwiftUI

struct QiblahCompassView: View {
    let bearing: Double
    /// Unwrapped true heading (`CompassHeading.continuousHeading`), already smoothed.
    let heading: Double
    let headingAvailable: Bool
    let accuracy: CompassAccuracy
    var compassSize: CGFloat = 260
    var showsAccuracyBanner = true
    var showsBearingText = true

    private var arrowSize: CGFloat {
        compassSize * 0.108
    }

    private var kaabaSize: CGFloat {
        compassSize * 0.09
    }

    private var ringColor: Color {
        switch accuracy {
        case .good: return Color.niyaSecondary.opacity(0.3)
        case .reduced: return Color.niyaGold.opacity(0.5)
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

            if showsAccuracyBanner && accuracy != .good && headingAvailable {
                accuracyBanner
            }

            if showsBearingText {
                bearingText
            }
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
        .rotationEffect(.degrees(-heading))
        // The heading is already smoothed; a short interactive spring only interpolates
        // between samples and retargets without restarting on each one.
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.9), value: heading)
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

            if showsAccuracyBanner {
                Text("Compass not available on this device")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
            }
        }
    }

    private var accuracyBanner: some View {
        let color: Color = accuracy == .reduced ? .niyaGold : .red
        return HStack(spacing: 6) {
            Image(systemName: accuracy == .reduced ? "exclamationmark.triangle" : "figure.wave")
                .font(.niyaCaption)
            Text(accuracy.message)
                .font(.niyaCaption2)
        }
        .foregroundStyle(color)
    }

    private var bearingText: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.columns")
                .foregroundStyle(Color.niyaTeal)
            Text(QiblahFormatting.bearingLabel(bearing))
                .font(.niyaBody)
                .foregroundStyle(Color.niyaText)
        }
    }

    private var cardinalDirections: [(label: String, angle: Double)] {
        [("N", 0), ("E", 90), ("S", 180), ("W", 270)]
    }
}

private extension CompassAccuracy {
    var message: String {
        switch self {
        case .good: return ""
        case .reduced: return "Compass accuracy is reduced"
        case .poor: return "Low accuracy — move away from metal objects"
        case .calibrating: return "Move your device in a figure-8 to calibrate"
        }
    }
}
