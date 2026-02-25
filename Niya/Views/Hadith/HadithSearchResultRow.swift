import SwiftUI

struct HadithSearchResultRow: View {
    let collectionId: String
    let hadith: Hadith
    let collectionName: String
    let hasGrades: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(collectionName)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaTeal)
                Text("#\(hadith.id)")
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaSecondary)

                Spacer()

                if hasGrades, let grade = HadithGrade.from(hadith.grade) {
                    Text(grade.displayName)
                        .font(.system(.caption2, design: .serif, weight: .medium))
                        .foregroundStyle(grade.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(grade.color.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Text(hadith.narrator)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaGold)
                .lineLimit(1)

            Text(hadith.text)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
