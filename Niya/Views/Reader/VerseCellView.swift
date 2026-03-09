import SwiftUI

struct VerseCellView: View {
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
    let onWordLongPress: (QuranWord) -> Void

    @AppStorage(StorageKey.followAlong) private var followAlong: Bool = false
    @Environment(WordDataService.self) private var wordDataService

    var body: some View {
        if followAlong, let verseData = wordDataService.words(surahId: surahId, ayahId: verse.id) {
            FollowAlongVerseView(
                verse: verse,
                surahId: surahId,
                verseData: verseData,
                isBookmarked: isBookmarked,
                bookmarkColor: bookmarkColor,
                isFirstVerse: isFirstVerse,
                onBookmark: onBookmark,
                onSetBookmarkColor: onSetBookmarkColor,
                onTafsir: onTafsir,
                onWordLongPress: onWordLongPress
            )
        } else {
            VerseRowView(
                verse: verse,
                surahId: surahId,
                script: script,
                isPlaying: isPlaying,
                isBookmarked: isBookmarked,
                bookmarkColor: bookmarkColor,
                isFirstVerse: isFirstVerse,
                onPlay: onPlay,
                onBookmark: onBookmark,
                onSetBookmarkColor: onSetBookmarkColor,
                onTafsir: onTafsir
            )
        }
    }
}
