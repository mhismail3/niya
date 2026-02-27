import SwiftUI

struct BookmarksView: View {
    @Environment(QuranDataService.self) private var quranDataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var quranBookmarks: [QuranBookmark] = []
    @State private var hadithBookmarks: [HadithBookmark] = []
    @State private var duaBookmarks: [DuaBookmark] = []

    private var hasAny: Bool {
        !quranBookmarks.isEmpty || !hadithBookmarks.isEmpty || !duaBookmarks.isEmpty
    }

    private var hadithGrouped: [(collection: HadithCollection, bookmarks: [HadithBookmark])] {
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
                if !hasAny {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Bookmark ayahs, hadiths, or duas to save them here")
                    )
                } else {
                    list
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadHadithCollections() }
        .task { await loadDuaData() }
        .onAppear { reload() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !quranBookmarks.isEmpty {
                    quranSection
                }
                if !hadithBookmarks.isEmpty {
                    hadithSection
                }
                if !duaBookmarks.isEmpty {
                    duaSection
                }
            }
        }
    }

    // MARK: - Quran

    private var quranSection: some View {
        Group {
            sectionHeader("Qur'an")

            ForEach(quranBookmarks, id: \.verseKey) { bookmark in
                let surah = quranDataService.surahs.first { $0.id == bookmark.surahId }
                let verse = quranDataService.verse(surahId: bookmark.surahId, ayahId: bookmark.ayahId)

                Button {
                    coordinator.navigateToAyah(surahId: bookmark.surahId, ayahId: bookmark.ayahId)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "diamond")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.niyaTeal.opacity(0.15))
                            Text("\(bookmark.ayahId)")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.niyaTeal)
                        }
                        .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(surah?.transliteration ?? "Surah \(bookmark.surahId)")
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaGold)
                            if let verse {
                                Text(verse.translation)
                                    .font(.niyaCaption)
                                    .foregroundStyle(Color.niyaText)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.niyaSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal)
            }
        }
    }

    // MARK: - Hadith

    private var hadithSection: some View {
        Group {
            sectionHeader("Hadith")

            ForEach(hadithGrouped, id: \.collection.id) { group in
                Text(group.collection.name)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaSecondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                ForEach(group.bookmarks, id: \.hadithKey) { bookmark in
                    if let hadith = hadithDataService.hadiths(for: bookmark.collectionId)
                        .first(where: { $0.id == bookmark.hadithId }) {
                        Button {
                            coordinator.navigateToHadith(
                                collectionId: bookmark.collectionId,
                                hadithId: bookmark.hadithId,
                                hasGrades: group.collection.hasGrades
                            )
                            dismiss()
                        } label: {
                            HStack {
                                HadithRowView(hadith: hadith, hasGrades: group.collection.hasGrades)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.niyaSecondary)
                            }
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

    // MARK: - Dua

    private var duaSection: some View {
        Group {
            sectionHeader("Dua")

            ForEach(duaBookmarks, id: \.duaKey) { bookmark in
                if let dua = duaDataService.dua(categoryId: bookmark.categoryId, duaId: bookmark.duaId) {
                    let categoryName = duaDataService.category(id: bookmark.categoryId)?.name ?? "Dua"

                    Button {
                        coordinator.navigateToDua(categoryId: bookmark.categoryId, duaId: bookmark.duaId)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Image(systemName: "diamond")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.niyaTeal.opacity(0.15))
                                Text("\(dua.number)")
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.niyaTeal)
                            }
                            .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(categoryName)
                                    .font(.niyaCaption)
                                    .foregroundStyle(Color.niyaGold)
                                Text(dua.translation)
                                    .font(.niyaCaption)
                                    .foregroundStyle(Color.niyaText)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.niyaSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.niyaSubheadline)
            .foregroundStyle(Color.niyaText)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 4)
    }

    private func reload() {
        quranBookmarks = QuranBookmarkStore(modelContext: modelContext).allBookmarks()
        hadithBookmarks = HadithBookmarkStore(modelContext: modelContext).allBookmarks()
        duaBookmarks = DuaBookmarkStore(modelContext: modelContext).allBookmarks()
    }

    private func loadHadithCollections() async {
        let bookmarks = HadithBookmarkStore(modelContext: modelContext).allBookmarks()
        for id in Set(bookmarks.map(\.collectionId)) {
            await hadithDataService.loadCollection(id)
        }
        reload()
    }

    private func loadDuaData() async {
        await duaDataService.load()
        reload()
    }
}
