import SwiftUI

struct TranslationBlockView: View {
    let name: String
    let text: String
    let isRTL: Bool
    let fontSize: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: fontSize - 2, weight: .medium))
                .foregroundStyle(Color.niyaTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            Text(text)
                .font(.system(size: fontSize, design: .serif))
                .foregroundStyle(Color.niyaSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
        .padding(.top, 4)
    }
}
