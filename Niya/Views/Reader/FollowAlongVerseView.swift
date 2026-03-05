import SwiftUI
import TipKit

struct FollowAlongVerseView: View {
    let verse: Verse
    let surahId: Int
    let verseData: VerseWordData
    let isBookmarked: Bool
    let bookmarkColor: BookmarkColor?
    let isFirstVerse: Bool
    let onBookmark: () -> Void
    let onSetBookmarkColor: (BookmarkColor?) -> Void
    let onTafsir: () -> Void

    private let playVerseTip = PlayVerseTip()
    private let bookmarkVerseTip = BookmarkVerseTip()
    private let tafsirVerseTip = TafsirVerseTip()
    @Environment(FollowAlongViewModel.self) private var followAlongVM
    @Environment(QuranDataService.self) private var dataService
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(\.highlightedAyahId) private var highlightedAyahId
    @AppStorage(StorageKey.showTranslation) private var showTranslation: Bool = true
    @AppStorage(StorageKey.followAlongTransliteration) private var showTransliteration = true
    @AppStorage(StorageKey.followAlongMeaning) private var showMeaning = true
    @AppStorage(StorageKey.translationFontSize) private var translationFontSize: Double = 16
    @AppStorage(StorageKey.translationIsRTL) private var translationIsRTL: Bool = false

    private var isActiveVerse: Bool {
        followAlongVM.currentVerseId == verse.id && followAlongVM.currentSurahId == surahId
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .center) {
                if !autoScrollVM.isEnabled {
                    playButton
                }
                bookmarkButton
                tafsirButton

                Spacer()

                verseNumberBadge
            }

            FlowLayout(spacing: 6, rightToLeft: true) {
                ForEach(verseData.w) { word in
                    WordView(
                        word: word,
                        highlightState: followAlongVM.highlightState(for: word, verseId: verse.id),
                        showTransliteration: showTransliteration,
                        showMeaning: showMeaning,
                        onTap: { if !followAlongVM.isPlaying { followAlongVM.tapWord(word, verseId: verse.id) } }
                    )
                }
            }

            if showTranslation, !verse.translation.isEmpty {
                let hasMultiple = !verse.extraTranslations.isEmpty

                if hasMultiple, let primary = dataService.selectedTranslations.first {
                    translationBlock(name: primary.name, text: verse.translation, isRTL: primary.isRTL)
                } else {
                    let primaryRTL = dataService.selectedTranslations.first?.isRTL ?? false
                    Text(verse.translation)
                        .font(.system(size: translationFontSize, design: .serif))
                        .foregroundStyle(Color.niyaSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, primaryRTL ? .rightToLeft : .leftToRight)
                }

                ForEach(verse.extraTranslations, id: \.name) { t in
                    translationBlock(name: t.name, text: t.text, isRTL: t.isRTL)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background {
            if isActiveVerse {
                Color.niyaGold.opacity(0.06)
                    .padding(.horizontal, -16)
            } else if highlightedAyahId == verse.id {
                Color.niyaGold.opacity(0.15)
                    .padding(.horizontal, -16)
            }
        }
        .animation(.easeOut(duration: 0.5), value: highlightedAyahId)
    }

    @ViewBuilder
    private var playButton: some View {
        let btn = Button {
            if isActiveVerse {
                followAlongVM.togglePlayPause()
            } else {
                followAlongVM.playVerse(surahId: surahId, ayahId: verse.id)
            }
        } label: {
            Image(systemName: isActiveVerse && followAlongVM.isPlaying ? "pause.circle.fill" : "play.circle")
                .font(.niyaVerseAction)
                .foregroundStyle(isActiveVerse ? Color.niyaGold : Color.niyaSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActiveVerse && followAlongVM.isPlaying ? "Pause verse \(verse.id)" : "Play verse \(verse.id)")
        if isFirstVerse {
            btn.popoverTip(playVerseTip)
        } else {
            btn
        }
    }

    @ViewBuilder
    private var bookmarkButton: some View {
        let btn = Button(action: onBookmark) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.niyaVerseAction)
                .foregroundStyle(isBookmarked ? (bookmarkColor?.color ?? .niyaGold) : Color.niyaSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isBookmarked ? "Remove bookmark, verse \(verse.id), \(bookmarkColor?.displayName ?? "Gold")" : "Bookmark verse \(verse.id)")
        .contextMenu {
            if isBookmarked {
                bookmarkColorMenu
            }
        }
        if isFirstVerse {
            btn.popoverTip(bookmarkVerseTip)
        } else {
            btn
        }
    }

    @ViewBuilder
    private var bookmarkColorMenu: some View {
        Section("Color") {
            Button { onSetBookmarkColor(nil) } label: {
                Label("Gold", systemImage: bookmarkColor == nil ? "checkmark.circle.fill" : "circle.fill")
            }
            .tint(.niyaGold)
            ForEach(BookmarkColor.allCases) { bc in
                Button { onSetBookmarkColor(bc) } label: {
                    Label(bc.displayName, systemImage: bookmarkColor == bc ? "checkmark.circle.fill" : "circle.fill")
                }
                .tint(bc.color)
            }
        }
        Section {
            Button(role: .destructive, action: onBookmark) {
                Label("Remove Bookmark", systemImage: "bookmark.slash")
            }
        }
    }

    @ViewBuilder
    private var tafsirButton: some View {
        let btn = Button(action: onTafsir) {
            Image(systemName: "text.book.closed")
                .font(.niyaVerseAction)
                .foregroundStyle(Color.niyaSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tafsir, verse \(verse.id)")
        if isFirstVerse {
            btn.popoverTip(tafsirVerseTip)
        } else {
            btn
        }
    }

    private func translationBlock(name: String, text: String, isRTL: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: translationFontSize - 2, weight: .medium))
                .foregroundStyle(Color.niyaTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            Text(text)
                .font(.system(size: translationFontSize, design: .serif))
                .foregroundStyle(Color.niyaSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
        .padding(.top, 4)
    }

    private var verseNumberBadge: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: 24))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(verse.id)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
        }
        .accessibilityLabel("Verse \(verse.id)")
    }
}
