import SwiftUI

struct HadithCollectionCard: View {
    let collection: HadithCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(collection.nameArabic)
                .font(.custom("NotoNaskhArabic-Regular", size: 18))
                .foregroundStyle(Color.niyaGold)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            Text(collection.name)
                .font(.niyaSubheadline)
                .foregroundStyle(Color.niyaText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Text("\(collection.totalHadiths) hadiths")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)

                Spacer()

                if collection.hasGrades {
                    Label("Graded", systemImage: "checkmark.seal")
                        .font(.niyaCaption2)
                        .foregroundStyle(Color.niyaTeal)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.niyaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
