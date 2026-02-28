import SwiftUI

struct VerseCellView: View {
    let verse: Verse
    let surahId: Int
    let script: QuranScript
    let showTranslation: Bool
    let isPlaying: Bool
    let isBookmarked: Bool
    let isFirstVerse: Bool
    let onPlay: () -> Void
    let onBookmark: () -> Void
    let onTafsir: () -> Void

    @AppStorage("followAlong") private var followAlong: Bool = false
    @Environment(WordDataService.self) private var wordDataService

    var body: some View {
        if followAlong, let verseData = wordDataService.words(surahId: surahId, ayahId: verse.id) {
            FollowAlongVerseView(
                verse: verse,
                surahId: surahId,
                verseData: verseData,
                isBookmarked: isBookmarked,
                isFirstVerse: isFirstVerse,
                onBookmark: onBookmark,
                onTafsir: onTafsir
            )
        } else {
            VerseRowView(
                verse: verse,
                surahId: surahId,
                script: script,
                showTranslation: showTranslation,
                isPlaying: isPlaying,
                isBookmarked: isBookmarked,
                isFirstVerse: isFirstVerse,
                onPlay: onPlay,
                onBookmark: onBookmark,
                onTafsir: onTafsir
            )
        }
    }
}
