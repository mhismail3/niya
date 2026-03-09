import SwiftUI

struct JuzProgressAccessory: View {
    let surahId: Int
    let ayahId: Int

    var body: some View {
        let juz = Juz.current(surahId: surahId, ayahId: ayahId)
        HStack(spacing: 8) {
            Text("Juz \(juz.number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.niyaText)
            ProgressView(value: juz.progress)
                .tint(Color.niyaGold)
                .frame(width: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .niyaGlass()
    }
}
