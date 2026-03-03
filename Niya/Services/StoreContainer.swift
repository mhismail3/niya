import SwiftUI
import SwiftData

@MainActor
final class StoreContainer {
    let quranBookmarks: QuranBookmarkStore
    let hadithBookmarks: HadithBookmarkStore
    let duaBookmarks: DuaBookmarkStore
    let readingPosition: ReadingPositionStore
    let downloads: DownloadStore
    let recentSearch: RecentSearchStore
    let recentHadith: RecentHadithStore
    let recentDua: RecentDuaStore

    init(modelContext: ModelContext) {
        quranBookmarks = QuranBookmarkStore(modelContext: modelContext)
        hadithBookmarks = HadithBookmarkStore(modelContext: modelContext)
        duaBookmarks = DuaBookmarkStore(modelContext: modelContext)
        readingPosition = ReadingPositionStore(modelContext: modelContext)
        downloads = DownloadStore(modelContext: modelContext)
        recentSearch = RecentSearchStore(modelContext: modelContext)
        recentHadith = RecentHadithStore(modelContext: modelContext)
        recentDua = RecentDuaStore(modelContext: modelContext)
    }
}

private struct StoreContainerKey: EnvironmentKey {
    static let defaultValue: StoreContainer? = nil
}

private struct HighlightedAyahKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var stores: StoreContainer? {
        get { self[StoreContainerKey.self] }
        set { self[StoreContainerKey.self] = newValue }
    }

    var highlightedAyahId: Int? {
        get { self[HighlightedAyahKey.self] }
        set { self[HighlightedAyahKey.self] = newValue }
    }
}
