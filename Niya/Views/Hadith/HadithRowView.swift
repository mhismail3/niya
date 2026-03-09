import SwiftUI

struct HadithRowView: View {
    let hadith: Hadith
    let hasGrades: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badgeView
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                if !hadith.narrator.isEmpty {
                    Text(hadith.narrator)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaGold)
                        .lineLimit(1)
                }

                if !hadith.text.isEmpty {
                    Text(hadith.text)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                } else if !hadith.arabic.isEmpty {
                    Text(hadith.arabic)
                        .font(.custom("NotoNaskhArabic-Regular", size: 14))
                        .foregroundStyle(Color.niyaText)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                if hasGrades, let grade = HadithGrade.from(hadith.grade) {
                    Text(grade.displayName)
                        .font(.system(.caption2, design: .serif, weight: .medium))
                        .foregroundStyle(grade.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(grade.color.opacity(0.1))
                        .clipShape(Capsule())
                } else if hasGrades, let gradeText = hadith.grade {
                    Text(gradeText)
                        .font(.system(.caption2, design: .serif, weight: .medium))
                        .foregroundStyle(Color.niyaSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.niyaSecondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var badgeView: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: 36))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(hadith.id)")
                .font(.system(size: hadith.id > 999 ? 10 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.niyaTeal)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(width: 48, height: 36)
    }
}
