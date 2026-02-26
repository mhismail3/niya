import SwiftUI

struct DuaCategoryRow: View {
    let category: DuaCategory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.niyaBody)
                    .foregroundStyle(Color.niyaText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(category.totalDuas)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.niyaTeal.opacity(0.12))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.niyaSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
