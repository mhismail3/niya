import SwiftUI

struct AudioPlayerBar: View {
    @Environment(AudioPlayerViewModel.self) private var vm
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.stores) private var stores
    @State private var isBookmarked = false
    @State private var bookmarkColor: BookmarkColor?

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
                    .frame(width: NiyaSize.touchTarget, height: NiyaSize.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous verse")
            .disabled(!isVerseMode)
            .opacity(isVerseMode ? 1 : 0.3)

            if vm.isLoading {
                ProgressView()
                    .tint(Color.niyaGold)
                    .frame(width: NiyaSize.touchTarget, height: NiyaSize.touchTarget)
            } else {
                Button(action: { isFollowAlong ? followAlongVM.togglePlayPause() : vm.togglePause() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.niyaGold)
                        .frame(width: NiyaSize.touchTarget, height: NiyaSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }

            Button(action: { isFollowAlong ? followAlongVM.nextVerse() : vm.nextVerse() }) {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundStyle(Color.niyaSecondary)
                    .frame(width: NiyaSize.touchTarget, height: NiyaSize.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next verse")
            .disabled(!isVerseMode)
            .opacity(isVerseMode ? 1 : 0.3)

            Button {
                if isFollowAlong {
                    guard let surahId = followAlongVM.currentSurahId,
                          let ayahId = followAlongVM.currentVerseId else { return }
                    stores.quranBookmarks.toggle(surahId: surahId, ayahId: ayahId)
                } else {
                    guard let vid = vm.currentVerseID else { return }
                    stores.quranBookmarks.toggle(surahId: vid.surahId, ayahId: vid.ayahId)
                }
                isBookmarked.toggle()
                if !isBookmarked { bookmarkColor = nil }
                NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.body)
                    .foregroundStyle(isBookmarked ? (bookmarkColor?.color ?? .niyaGold) : Color.niyaSecondary)
                    .frame(width: NiyaSize.touchTarget, height: NiyaSize.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isBookmarked ? "Remove bookmark, \(bookmarkColor?.displayName ?? "Gold")" : "Add bookmark")
            .contextMenu {
                if isBookmarked {
                    Section("Color") {
                        Button { setBarBookmarkColor(nil) } label: {
                            Label("Gold", systemImage: bookmarkColor == nil ? "checkmark.circle.fill" : "circle.fill")
                        }
                        .tint(.niyaGold)
                        ForEach(BookmarkColor.allCases) { bc in
                            Button { setBarBookmarkColor(bc) } label: {
                                Label(bc.displayName, systemImage: bookmarkColor == bc ? "checkmark.circle.fill" : "circle.fill")
                            }
                            .tint(bc.color)
                        }
                    }
                    Section {
                        Button(role: .destructive) {
                            if isFollowAlong {
                                guard let surahId = followAlongVM.currentSurahId,
                                      let ayahId = followAlongVM.currentVerseId else { return }
                                stores.quranBookmarks.toggle(surahId: surahId, ayahId: ayahId)
                            } else {
                                guard let vid = vm.currentVerseID else { return }
                                stores.quranBookmarks.toggle(surahId: vid.surahId, ayahId: vid.ayahId)
                            }
                            isBookmarked = false
                            bookmarkColor = nil
                            NotificationCenter.default.post(name: .bookmarkChanged, object: nil)
                        } label: {
                            Label("Remove Bookmark", systemImage: "bookmark.slash")
                        }
                    }
                }
            }
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
                .accessibilityLabel("Stop audio")
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
                .accessibilityLabel("Go to verse")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .modifier(StableGlassModifier())
        .onChange(of: vm.currentVerseID) { _, vid in
            guard let vid else {
                if !isFollowAlong { isBookmarked = false; bookmarkColor = nil }
                return
            }
            isBookmarked = stores.quranBookmarks
                .isBookmarked(surahId: vid.surahId, ayahId: vid.ayahId)
            bookmarkColor = isBookmarked
                ? stores.quranBookmarks.allBookmarks()
                    .first { $0.surahId == vid.surahId && $0.ayahId == vid.ayahId }?.bookmarkColor
                : nil
        }
        .onChange(of: followAlongVM.currentVerseId) { _, ayahId in
            guard let surahId = followAlongVM.currentSurahId, let ayahId else {
                if isFollowAlong { isBookmarked = false; bookmarkColor = nil }
                return
            }
            isBookmarked = stores.quranBookmarks
                .isBookmarked(surahId: surahId, ayahId: ayahId)
            bookmarkColor = isBookmarked
                ? stores.quranBookmarks.allBookmarks()
                    .first { $0.surahId == surahId && $0.ayahId == ayahId }?.bookmarkColor
                : nil
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
                .frame(width: NiyaSize.touchTarget, height: NiyaSize.touchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Repeat, \(currentLoopCount == 1 ? "off" : "\(currentLoopCount) times")")
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
        .accessibilityLabel("Playback speed, \(speedLabel(currentSpeed))")
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        if speed == 0.5 { return "0.5x" }
        if speed == 0.75 { return "0.75x" }
        return "1.25x"
    }

    private func setBarBookmarkColor(_ color: BookmarkColor?) {
        if isFollowAlong {
            guard let surahId = followAlongVM.currentSurahId,
                  let ayahId = followAlongVM.currentVerseId else { return }
            stores.quranBookmarks.setColor(color, surahId: surahId, ayahId: ayahId)
        } else {
            guard let vid = vm.currentVerseID else { return }
            stores.quranBookmarks.setColor(color, surahId: vid.surahId, ayahId: vid.ayahId)
        }
        bookmarkColor = color
    }
}

private struct StableGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.background {
                Color.clear.glassEffect()
            }
        } else {
            content.background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }
}
