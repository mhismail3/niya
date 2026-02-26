import SwiftUI

struct RecentHadithCard: View {
    let hadith: Hadith
    let collectionName: String
    let visitedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(collectionName)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaGold)
                .lineLimit(1)

            Text(hadith.text)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
                .lineLimit(3)

            Spacer(minLength: 0)

            Text("Hadith #\(hadith.id)")
                .font(.niyaCaption2)
                .foregroundStyle(Color.niyaSecondary)

            Text(visitedAt.relativeFormatted)
                .font(.niyaCaption2)
                .foregroundStyle(Color.niyaSecondary)
        }
        .padding(12)
        .frame(width: 170)
        .niyaCard()
    }
}
