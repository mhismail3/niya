import SwiftUI

struct DuaSearchResultRow: View {
    let categoryName: String
    let dua: Dua

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(categoryName)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaTeal)
                Text(dua.id)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaSecondary)
                Spacer()
                if let rep = dua.repeat, rep > 1 {
                    Text("\(rep)x")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.niyaTeal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.niyaTeal.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Text(dua.translation ?? dua.arabic)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
