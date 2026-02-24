import SwiftUI

struct NiyaCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.niyaSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct BismillahHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 16) {
            Text("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ")
                .font(.custom(QuranScript.hafs.fontName, size: 26))
                .foregroundStyle(Color.niyaGold)
                .frame(maxWidth: .infinity, alignment: .center)
                .environment(\.layoutDirection, .rightToLeft)
            content
        }
    }
}

extension View {
    func niyaCard() -> some View {
        modifier(NiyaCardModifier())
    }

    func bismillahHeader() -> some View {
        modifier(BismillahHeaderModifier())
    }
}
