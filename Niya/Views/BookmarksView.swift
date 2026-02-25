import SwiftUI

struct BookmarksView: View {
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(\.modelContext) private var modelContext
    @State private var hadithBookmarks: [HadithBookmark] = []

    private var grouped: [(collection: HadithCollection, bookmarks: [HadithBookmark])] {
        var result: [(collection: HadithCollection, bookmarks: [HadithBookmark])] = []
        let byCollection = Dictionary(grouping: hadithBookmarks, by: \.collectionId)
        for collection in hadithDataService.collections {
            if let items = byCollection[collection.id], !items.isEmpty {
                result.append((collection, items))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if hadithBookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Bookmark hadiths to save them here")
                    )
                } else {
                    list
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadBookmarkedCollections() }
        .onAppear { reload() }
    }

    private var list: some View {
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
                        if let hadith = hadithDataService.hadiths(for: bookmark.collectionId)
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

    private func reload() {
        hadithBookmarks = HadithBookmarkStore(modelContext: modelContext).allBookmarks()
    }

    private func loadBookmarkedCollections() async {
        let bookmarks = HadithBookmarkStore(modelContext: modelContext).allBookmarks()
        for id in Set(bookmarks.map(\.collectionId)) {
            await hadithDataService.loadCollection(id)
        }
        reload()
    }
}
