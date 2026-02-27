import SwiftUI

struct AudioPlayerBar: View {
    @Environment(AudioPlayerViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext
    @State private var isBookmarked = false

    private var isVerseMode: Bool { vm.currentVerseID != nil }

    var body: some View {
        HStack(spacing: 16) {
            repeatMenu
            speedMenu

            Button(action: { vm.previousVerse() }) {
                Image(systemName: "backward.fill")
                    .font(.body)
                    .foregroundStyle(Color.niyaSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isVerseMode)
            .opacity(isVerseMode ? 1 : 0.3)

            if vm.isLoading {
                ProgressView()
                    .tint(Color.niyaGold)
                    .frame(width: 44, height: 44)
            } else {
                Button(action: { vm.togglePause() }) {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.niyaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(action: { vm.nextVerse() }) {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundStyle(Color.niyaSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isVerseMode)
            .opacity(isVerseMode ? 1 : 0.3)

            Button {
                guard let vid = vm.currentVerseID else { return }
                let store = QuranBookmarkStore(modelContext: modelContext)
                store.toggle(surahId: vid.surahId, ayahId: vid.ayahId)
                isBookmarked.toggle()
                NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.body)
                    .foregroundStyle(isBookmarked ? Color.niyaGold : Color.niyaSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isVerseMode)
            .opacity(isVerseMode ? 1 : 0.3)

            Button(action: { vm.stop() }) {
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
        .contentShape(Rectangle())
        .glassEffect()
        .onChange(of: vm.currentVerseID) { _, vid in
            guard let vid else { isBookmarked = false; return }
            isBookmarked = QuranBookmarkStore(modelContext: modelContext)
                .isBookmarked(surahId: vid.surahId, ayahId: vid.ayahId)
        }
    }

    private var repeatMenu: some View {
        Menu {
            ForEach([1, 2, 3, 5, 10], id: \.self) { count in
                Button {
                    vm.loopCount = count
                } label: {
                    HStack {
                        Text(count == 1 ? "No Repeat" : "\(count)x")
                        if vm.loopCount == count {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: vm.loopCount > 1 ? "repeat.circle.fill" : "repeat")
                .font(.body)
                .foregroundStyle(vm.loopCount > 1 ? Color.niyaGold : Color.niyaSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!isVerseMode)
        .opacity(isVerseMode ? 1 : 0.3)
    }

    private var speedMenu: some View {
        Menu {
            ForEach([Float(0.5), 0.75, 1.0, 1.25], id: \.self) { speed in
                Button {
                    vm.setSpeed(speed)
                } label: {
                    HStack {
                        Text(speedLabel(speed))
                        if vm.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(speedLabel(vm.playbackSpeed))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.niyaSecondary.opacity(0.15), in: .capsule)
                .foregroundStyle(Color.niyaText)
        }
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        if speed == 0.5 { return "0.5x" }
        if speed == 0.75 { return "0.75x" }
        return "1.25x"
    }
}
