import SwiftUI

struct SurahRowView: View {
    let surah: Surah

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.niyaTeal.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text("\(surah.id)")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.niyaTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(surah.transliteration)
                    .font(.niyaBody)
                    .foregroundStyle(Color.niyaText)
                HStack(spacing: 6) {
                    Text(surah.translation)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                    Text("·")
                        .foregroundStyle(Color.niyaSecondary)
                    Text("\(surah.totalVerses) verses")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                    Text("·")
                        .foregroundStyle(Color.niyaSecondary)
                    Text(surah.isMakkan ? "Makkan" : "Madinan")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                }
            }

            Spacer()

            Text(surah.name)
                .font(.custom("KFGQPCUthmanicScriptHAFS-Regular", size: 20))
                .foregroundStyle(Color.niyaGold)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.vertical, 4)
    }
}
