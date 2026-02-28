import SwiftUI

struct HadithChapterRow: View {
    let chapter: HadithChapter

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.niyaTeal.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text("\(chapter.id)")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.niyaTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title.isEmpty ? chapter.titleArabic : chapter.title)
                    .font(chapter.title.isEmpty
                        ? .custom("NotoNaskhArabic-Regular", size: 16)
                        : .niyaBody)
                    .foregroundStyle(Color.niyaText)
                    .lineLimit(2)
                    .environment(\.layoutDirection, chapter.title.isEmpty ? .rightToLeft : .leftToRight)
                Text("\(chapter.hadithCount) hadiths")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
            }

            Spacer()

            if !chapter.title.isEmpty {
                Text(chapter.titleArabic)
                    .font(.custom("NotoNaskhArabic-Regular", size: 16))
                    .foregroundStyle(Color.niyaGold)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }
}
