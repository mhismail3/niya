import SwiftUI

struct RecentDuaCard: View {
    let dua: Dua
    let categoryName: String
    let visitedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(categoryName)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaGold)
                .lineLimit(1)

            Text(dua.translation ?? dua.arabic)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(visitedAt.relativeFormatted)
                .font(.niyaCaption2)
                .foregroundStyle(Color.niyaSecondary)
        }
        .padding(12)
        .frame(width: 170)
        .niyaCard()
    }
}
