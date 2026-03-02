import SwiftUI

struct AutoScrollBar: View {
    @Environment(AutoScrollViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 16) {
            Button(action: vm.decrementSpeed) {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(vm.wordsPerMinute > AutoScrollViewModel.minWPM ? Color.niyaText : Color.niyaSecondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(vm.wordsPerMinute <= AutoScrollViewModel.minWPM)

            Text("\(vm.wordsPerMinute) WPM")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.niyaText)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.niyaSecondary.opacity(0.15), in: .capsule)

            Button(action: vm.incrementSpeed) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(vm.wordsPerMinute < AutoScrollViewModel.maxWPM ? Color.niyaText : Color.niyaSecondary.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(vm.wordsPerMinute >= AutoScrollViewModel.maxWPM)

            Button(action: vm.toggleScrolling) {
                Image(systemName: vm.isScrolling ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.niyaGold)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: vm.stop) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.niyaSecondary)
                    .padding(8)
                    .background(Color.niyaSecondary.opacity(0.15), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .niyaGlass()
    }
}
