import SwiftUI

struct AudioPlayerBar: View {
    @Environment(AudioPlayerViewModel.self) private var vm
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @State private var isBookmarked = false

    private var isFollowAlong: Bool { vm.isFollowAlongActive }
    private var isVerseMode: Bool { vm.currentVerseID != nil || isFollowAlong }
    private var isPlaying: Bool { isFollowAlong ? followAlongVM.isPlaying : vm.isPlaying }

    var body: some View {
        HStack(spacing: 16) {
            speedMenu
            repeatMenu

            Button(action: { isFollowAlong ? followAlongVM.previousVerse() : vm.previousVerse() }) {
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
                Button(action: { isFollowAlong ? followAlongVM.togglePlayPause() : vm.togglePause() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.niyaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(action: { isFollowAlong ? followAlongVM.nextVerse() : vm.nextVerse() }) {
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
                if isFollowAlong {
                    guard let surahId = followAlongVM.currentSurahId,
                          let ayahId = followAlongVM.currentVerseId else { return }
                    let store = QuranBookmarkStore(modelContext: modelContext)
                    store.toggle(surahId: surahId, ayahId: ayahId)
                } else {
                    guard let vid = vm.currentVerseID else { return }
                    let store = QuranBookmarkStore(modelContext: modelContext)
                    store.toggle(surahId: vid.surahId, ayahId: vid.ayahId)
                }
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

            if coordinator.isReaderVisible {
                Button(action: {
                    followAlongVM.stopTracking()
                    vm.stop()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.niyaSecondary)
                        .padding(8)
                        .background(Color.niyaSecondary.opacity(0.15), in: .circle)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    let surahId = vm.currentVerseID?.surahId
                        ?? followAlongVM.currentSurahId
                        ?? vm.currentSurahId ?? 1
                    let ayahId = vm.currentVerseID?.ayahId
                        ?? followAlongVM.currentVerseId
                        ?? 1
                    coordinator.navigateToAyah(surahId: surahId, ayahId: ayahId)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.niyaTeal)
                        .padding(8)
                        .background(Color.niyaTeal.opacity(0.15), in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .niyaGlass()
        .onChange(of: vm.currentVerseID) { _, vid in
            guard let vid else {
                if !isFollowAlong { isBookmarked = false }
                return
            }
            isBookmarked = QuranBookmarkStore(modelContext: modelContext)
                .isBookmarked(surahId: vid.surahId, ayahId: vid.ayahId)
        }
        .onChange(of: followAlongVM.currentVerseId) { _, ayahId in
            guard let surahId = followAlongVM.currentSurahId, let ayahId else {
                if isFollowAlong { isBookmarked = false }
                return
            }
            isBookmarked = QuranBookmarkStore(modelContext: modelContext)
                .isBookmarked(surahId: surahId, ayahId: ayahId)
        }
    }

    private var currentLoopCount: Int {
        isFollowAlong ? followAlongVM.loopCount : vm.loopCount
    }

    private var currentSpeed: Float {
        isFollowAlong ? followAlongVM.playbackSpeed : vm.playbackSpeed
    }

    private var repeatMenu: some View {
        Menu {
            ForEach([1, 2, 3, 5, 10], id: \.self) { count in
                Button {
                    isFollowAlong ? followAlongVM.setLoopCount(count) : vm.setLoopCount(count)
                } label: {
                    HStack {
                        Text(count == 1 ? "No Repeat" : "\(count)x")
                        if currentLoopCount == count {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: currentLoopCount > 1 ? "repeat.circle.fill" : "repeat")
                .font(.body)
                .foregroundStyle(currentLoopCount > 1 ? Color.niyaGold : Color.niyaSecondary)
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
                    isFollowAlong ? followAlongVM.setSpeed(speed) : vm.setSpeed(speed)
                } label: {
                    HStack {
                        Text(speedLabel(speed))
                        if currentSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(speedLabel(currentSpeed))
                .font(.caption.weight(.semibold))
                .fixedSize()
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
