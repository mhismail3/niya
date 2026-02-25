import SwiftUI

struct HadithBookmarksView: View {
    @Environment(HadithDataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext
    @State private var bookmarks: [HadithBookmark] = []

    private var grouped: [(collection: HadithCollection, bookmarks: [HadithBookmark])] {
        var result: [(collection: HadithCollection, bookmarks: [HadithBookmark])] = []
        let byCollection = Dictionary(grouping: bookmarks, by: \.collectionId)
        for collection in dataService.collections {
            if let items = byCollection[collection.id], !items.isEmpty {
                result.append((collection, items))
            }
        }
        return result
    }

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Bookmark hadiths to save them here")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(grouped, id: \.collection.id) { group in
                            Text(group.collection.name)
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaSecondary)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 4)

                            ForEach(group.bookmarks, id: \.hadithKey) { bookmark in
                                if let hadith = dataService.hadiths(for: bookmark.collectionId)
                                    .first(where: { $0.id == bookmark.hadithId }) {
                                    NavigationLink {
                                        HadithDetailView(
                                            hadith: hadith,
                                            collectionId: bookmark.collectionId,
                                            hasGrades: group.collection.hasGrades
                                        )
                                    } label: {
                                        HadithRowView(hadith: hadith, hasGrades: group.collection.hasGrades)
                                            .padding(.horizontal)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.niyaBackground)
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadBookmarkedCollections() }
        .onAppear { reload() }
    }

    private func reload() {
        let store = HadithBookmarkStore(modelContext: modelContext)
        bookmarks = store.allBookmarks()
    }

    private func loadBookmarkedCollections() async {
        let store = HadithBookmarkStore(modelContext: modelContext)
        let all = store.allBookmarks()
        let collectionIds = Set(all.map(\.collectionId))
        for id in collectionIds {
            await dataService.loadCollection(id)
        }
        reload()
    }
}
