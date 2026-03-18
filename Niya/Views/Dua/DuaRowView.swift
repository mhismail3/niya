import SwiftUI

struct DuaRowView: View {
    let dua: Dua
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badgeView
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(dua.translation ?? dua.arabic)
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let rep = dua.repeat, rep > 1 {
                    Text("Recite \(rep)x")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.niyaTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.niyaTeal.opacity(0.1))
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
            Text("\(index)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(width: 48, height: 36)
    }
}
