import SwiftUI

struct QiblahCompassView: View {
    let bearing: Double
    let heading: Double
    let headingAvailable: Bool
    let needsCalibration: Bool
    var compact: Bool = false

    private var compassRotation: Double {
        -heading
    }

    private var needleRotation: Double {
        bearing
    }

    private var compassSize: CGFloat {
        compact ? 160 : 260
    }

    var body: some View {
        VStack(spacing: compact ? 8 : 16) {
            if !headingAvailable {
                staticCompass
            } else if needsCalibration {
                ZStack {
                    compassDial
                    calibrationOverlay
                }
            } else {
                compassDial
            }

            bearingText
        }
    }

    private var compassDial: some View {
        ZStack {
            // Compass ring
            Circle()
                .stroke(Color.niyaSecondary.opacity(0.3), lineWidth: 2)
                .frame(width: compassSize, height: compassSize)

            // Direction markers
            ForEach(0..<36, id: \.self) { i in
                let angle = Double(i) * 10
                let isMajor = i % 9 == 0
                Rectangle()
                    .fill(isMajor ? Color.niyaText : Color.niyaSecondary.opacity(0.4))
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 16 : 8)
                    .offset(y: -compassSize / 2 + (isMajor ? 8 : 4))
                    .rotationEffect(.degrees(angle))
            }

            // Cardinal direction labels
            ForEach(cardinalDirections, id: \.label) { dir in
                Text(dir.label)
                    .font(.niyaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(dir.label == "N" ? Color.red : Color.niyaText)
                    .offset(y: -compassSize / 2 + 28)
                    .rotationEffect(.degrees(dir.angle))
            }

            // Qiblah needle
            VStack(spacing: 0) {
                Image(systemName: "arrow.up")
                    .font(.system(size: compact ? 20 : 28, weight: .bold))
                    .foregroundStyle(Color.niyaTeal)
                Image(systemName: "building.columns")
                    .font(.system(size: compact ? 10 : 14))
                    .foregroundStyle(Color.niyaTeal)
            }
            .rotationEffect(.degrees(needleRotation))
            .animation(.easeInOut(duration: 0.3), value: needleRotation)
        }
        .rotationEffect(.degrees(compassRotation))
        .animation(.easeInOut(duration: 0.3), value: compassRotation)
    }

    private var staticCompass: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.niyaSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: compassSize, height: compassSize)

                Image(systemName: "building.columns")
                    .font(.system(size: compact ? 20 : 30))
                    .foregroundStyle(Color.niyaTeal)

                VStack(spacing: 0) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: compact ? 16 : 22, weight: .bold))
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

    private var calibrationOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "figure.wave")
                    .font(.title3)
                Text("Move your device in a figure-8 pattern")
                    .font(.niyaCaption)
            }
            .foregroundStyle(Color.niyaGold)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var bearingText: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.columns")
                .foregroundStyle(Color.niyaTeal)
            Text("\(Int(bearing))° \(cardinalDirection(for: bearing))")
                .font(compact ? .niyaCaption : .niyaBody)
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
