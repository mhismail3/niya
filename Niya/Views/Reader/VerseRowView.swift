import SwiftUI
import TipKit

struct VerseRowView: View {
    let verse: Verse
    let surahId: Int
    let script: QuranScript
    let isPlaying: Bool
    let isBookmarked: Bool
    let bookmarkColor: BookmarkColor?
    let isFirstVerse: Bool
    let onPlay: () -> Void
    let onBookmark: () -> Void
    let onSetBookmarkColor: (BookmarkColor?) -> Void
    let onTafsir: () -> Void

    private let playVerseTip = PlayVerseTip()
    private let bookmarkVerseTip = BookmarkVerseTip()
    private let tafsirVerseTip = TafsirVerseTip()
    @Environment(TajweedService.self) private var tajweedService
    @Environment(QuranDataService.self) private var dataService
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(\.highlightedAyahId) private var highlightedAyahId
    @Environment(\.showTajweedGuide) private var showTajweedGuide
    @AppStorage(StorageKey.showTranslation) private var showTranslation: Bool = true
    @AppStorage(StorageKey.showTajweed) private var showTajweed: Bool = true
    @AppStorage(StorageKey.arabicFontSize) private var arabicFontSize: Double = 28
    @AppStorage(StorageKey.translationFontSize) private var translationFontSize: Double = 16
    @AppStorage(StorageKey.translationIsRTL) private var translationIsRTL: Bool = false
    @State private var activeTap: TajweedTap?
    @State private var tooltipWidth: CGFloat = 160
    @State private var dismissTask: Task<Void, Never>?

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

            if showTajweed && script == .hafs, let tv = tajweedService.verse(surahId: surahId, ayahId: verse.id) {
                TajweedTextView(verse: tv, displayText: Self.stripUnsupportedMarks(verse.text), fontSize: arabicFontSize) { tap in
                    handleTajweedTap(tap)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .overlay {
                    GeometryReader { geo in
                        if let tap = activeTap {
                            let halfW = tooltipWidth / 2
                            let clampedX = min(max(tap.position.x, halfW), geo.size.width - halfW)
                            tajweedTooltip(for: tap.rule)
                                .background {
                                    GeometryReader { tipGeo in
                                        Color.clear
                                            .onAppear { tooltipWidth = tipGeo.size.width }
                                            .onChange(of: tap.rule) { _, _ in
                                                tooltipWidth = tipGeo.size.width
                                            }
                                    }
                                }
                                .position(x: clampedX, y: tap.position.y - 24)
                        }
                    }
                }
                .transition(.opacity)
                .onScrollVisibilityDismiss { dismissTooltip() }
            } else {
                Text(Self.stripUnsupportedMarks(verse.text))
                    .font(.quranText(script: script, size: arabicFontSize))
                    .foregroundStyle(Color.niyaText)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
            if isPlaying {
                Color.niyaGold.opacity(0.06)
                    .padding(.horizontal, -16)
            } else if highlightedAyahId == verse.id {
                Color.niyaGold.opacity(0.15)
                    .padding(.horizontal, -16)
            }
        }
        .animation(.easeOut(duration: 0.5), value: highlightedAyahId)
        .onChange(of: showTajweed) { _, on in
            if !on { dismissTooltip() }
        }
    }

    @ViewBuilder
    private var playButton: some View {
        let btn = Button(action: onPlay) {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                .font(.niyaVerseAction)
                .foregroundStyle(isPlaying ? Color.niyaGold : Color.niyaSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause verse \(verse.id)" : "Play verse \(verse.id)")
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
        BookmarkColorMenuContent(
            currentColor: bookmarkColor,
            onSetColor: onSetBookmarkColor,
            onRemove: onBookmark
        )
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

    private func handleTajweedTap(_ tap: TajweedTap?) {
        dismissTask?.cancel()

        guard let tap else {
            withAnimation(.easeOut(duration: 0.2)) { activeTap = nil }
            return
        }

        // Tap same region → dismiss
        if let current = activeTap, current.rule == tap.rule,
           abs(current.position.x - tap.position.x) < 20,
           abs(current.position.y - tap.position.y) < 20 {
            withAnimation(.easeOut(duration: 0.2)) { activeTap = nil }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) { activeTap = tap }

        // Auto-dismiss after 5 seconds
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { activeTap = nil }
        }
    }

    private func dismissTooltip() {
        dismissTask?.cancel()
        activeTap = nil
    }

    private func tajweedTooltip(for rule: TajweedRule) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(rule.color)
                .frame(width: 10, height: 10)
            Text(rule.displayName)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
            Text(rule.arabicName)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.niyaSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.niyaSurface, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .fixedSize()
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
        .onTapGesture {
            dismissTask?.cancel()
            withAnimation(.easeOut(duration: 0.3)) { activeTap = nil }
            showTajweedGuide()
        }
    }

    private func translationBlock(name: String, text: String, isRTL: Bool) -> some View {
        TranslationBlockView(name: name, text: text, isRTL: isRTL, fontSize: translationFontSize)
    }

    private static func stripUnsupportedMarks(_ text: String) -> String {
        String(text.unicodeScalars.filter { !TajweedService.unsupportedQuranMarks.contains($0.value) })
    }

    private var verseNumberBadge: some View {
        VerseNumberBadge(verseId: verse.id)
    }
}
