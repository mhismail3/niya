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

private struct StoreContainerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: StoreContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: AudioDownload.self, ReadingPosition.self, RecentSearch.self,
            HadithBookmark.self, QuranBookmark.self, DuaBookmark.self,
            RecentHadith.self, RecentDua.self,
            configurations: config
        )
        return StoreContainer(modelContext: container.mainContext)
    }()
}

private struct HighlightedAyahKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

private struct ShowTajweedGuideKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var stores: StoreContainer {
        get { self[StoreContainerKey.self] }
        set { self[StoreContainerKey.self] = newValue }
    }

    var highlightedAyahId: Int? {
        get { self[HighlightedAyahKey.self] }
        set { self[HighlightedAyahKey.self] = newValue }
    }

    var showTajweedGuide: () -> Void {
        get { self[ShowTajweedGuideKey.self] }
        set { self[ShowTajweedGuideKey.self] = newValue }
    }
}
