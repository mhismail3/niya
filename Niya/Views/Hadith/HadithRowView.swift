import SwiftUI

struct HadithRowView: View {
    let hadith: Hadith
    let hasGrades: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                badgeView
                gradeLabel
            }
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var badgeView: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: 30))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(hadith.id)")
                .font(.system(size: hadith.id > 999 ? 9 : 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.niyaTeal)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(width: 48, height: 30)
    }

    @ViewBuilder
    private var gradeLabel: some View {
        if hasGrades, let grade = HadithGrade.from(hadith.grade) {
            Text(grade.displayName)
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundStyle(grade.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(grade.color.opacity(0.1))
                .clipShape(Capsule())
                .lineLimit(1)
                .fixedSize()
        } else if hasGrades, let gradeText = hadith.grade {
            Text(gradeText)
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundStyle(Color.niyaSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.niyaSecondary.opacity(0.1))
                .clipShape(Capsule())
                .lineLimit(1)
                .fixedSize()
        }
    }
}
