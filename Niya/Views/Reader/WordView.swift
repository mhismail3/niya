import SwiftUI

struct WordView: View {
    let word: QuranWord
    let highlightState: WordHighlightState
    let showTransliteration: Bool
    let showMeaning: Bool
    let onTap: () -> Void
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(word.displayText)
                    .font(.custom(QuranScript.hafs.fontName, size: arabicFontSize))
                    .fontWeight(highlightState == .current ? .bold : .regular)
                    .foregroundStyle(arabicColor)

                if showTransliteration {
                    Text(word.tr)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(secondaryColor)
                }

                if showMeaning {
                    Text(word.en)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(secondaryColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                if highlightState == .current {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.niyaGold.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: highlightState)
    }

    private var arabicColor: Color {
        switch highlightState {
        case .current: .niyaGold
        case .completed: .niyaText.opacity(0.5)
        case .upcoming: .niyaText
        }
    }

    private var secondaryColor: Color {
        switch highlightState {
        case .current: .niyaGold.opacity(0.85)
        case .completed: .niyaSecondary.opacity(0.45)
        case .upcoming: .niyaSecondary
        }
    }
}
