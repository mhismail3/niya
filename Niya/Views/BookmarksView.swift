import SwiftUI

struct BookmarksView: View {
    @Environment(QuranDataService.self) private var quranDataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.stores) private var stores
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKey.selectedScript) private var storedScript: QuranScript = .hafs
    @State private var quranBookmarks: [QuranBookmark] = []
    @State private var hadithBookmarks: [HadithBookmark] = []
    @State private var duaBookmarks: [DuaBookmark] = []
    @State private var colorFilter: ColorFilter = .all

    enum ColorFilter: Hashable {
        case all
        case color(BookmarkColor?)
    }

    private var hasAny: Bool {
        !quranBookmarks.isEmpty || !hadithBookmarks.isEmpty || !duaBookmarks.isEmpty
    }

    private var filteredQuranBookmarks: [QuranBookmark] {
        switch colorFilter {
        case .all: return quranBookmarks
        case .color(let c): return quranBookmarks.filter { $0.bookmarkColor == c }
        }
    }

    private var filteredHadithBookmarks: [HadithBookmark] {
        switch colorFilter {
        case .all: return hadithBookmarks
        case .color(let c): return hadithBookmarks.filter { $0.bookmarkColor == c }
        }
    }

    private var filteredDuaBookmarks: [DuaBookmark] {
        switch colorFilter {
        case .all: return duaBookmarks
        case .color(let c): return duaBookmarks.filter { $0.bookmarkColor == c }
        }
    }

    private var hadithGrouped: [(collection: HadithCollection, bookmarks: [HadithBookmark])] {
        var result: [(collection: HadithCollection, bookmarks: [HadithBookmark])] = []
        let byCollection = Dictionary(grouping: filteredHadithBookmarks, by: \.collectionId)
        for collection in hadithDataService.collections {
            if let items = byCollection[collection.id], !items.isEmpty {
                result.append((collection, items))
            }
        }
        return result
    }

    private var hasFilteredResults: Bool {
        !filteredQuranBookmarks.isEmpty || !filteredHadithBookmarks.isEmpty || !filteredDuaBookmarks.isEmpty
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
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await loadHadithCollections() }
        .task { await loadDuaData() }
        .onAppear { reload() }
    }

    private var list: some View {
        List {
            Section {
                colorFilterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !hasFilteredResults {
                Section {
                    Text("No bookmarks match this filter")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                if !filteredQuranBookmarks.isEmpty {
                    quranSection
                }
                if !filteredHadithBookmarks.isEmpty {
                    hadithSection
                }
                if !filteredDuaBookmarks.isEmpty {
                    duaSection
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Color Filter Bar

    private var colorFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", color: nil, isSelected: colorFilter == .all) {
                    colorFilter = .all
                }
                filterChip("Gold", color: .niyaGold, isSelected: colorFilter == .color(nil)) {
                    colorFilter = .color(nil)
                }
                ForEach(BookmarkColor.allCases) { bc in
                    filterChip(bc.displayName, color: bc.color, isSelected: colorFilter == .color(bc)) {
                        colorFilter = .color(bc)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    private func filterChip(_ label: String, color: Color?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.system(.caption, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.niyaGold.opacity(0.15) : Color.niyaSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.niyaGold.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.niyaGold : Color.niyaSecondary)
    }

    // MARK: - Quran

    private var quranSection: some View {
        Section {
            ForEach(filteredQuranBookmarks, id: \.verseKey) { bookmark in
                let surah = quranDataService.surahs.first { $0.id == bookmark.surahId }
                let verse = quranDataService.verses(for: bookmark.surahId, script: storedScript)
                    .first { $0.id == bookmark.ayahId }
                let badgeColor = bookmark.bookmarkColor?.color ?? .niyaTeal

                HStack(spacing: 12) {
                    ZStack {
                        Image(systemName: "diamond")
                            .font(.system(size: 32))
                            .foregroundStyle(badgeColor.opacity(0.15))
                        Text("\(bookmark.ayahId)")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(badgeColor)
                    }
                    .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(surah?.transliteration ?? "Surah \(bookmark.surahId)")
                            .font(.niyaCaption)
                            .foregroundStyle(Color.niyaGold)

                        if let verse {
                            Text(verse.text)
                                .font(.quranText(script: storedScript, size: 20))
                                .foregroundStyle(Color.niyaText)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .lineLimit(2)

                            let translations = buildTranslations(verse: verse)
                            let showEditionName = translations.count > 1

                            ForEach(Array(translations.prefix(2).enumerated()), id: \.offset) { _, t in
                                VStack(alignment: .leading, spacing: 1) {
                                    if showEditionName {
                                        Text(t.name)
                                            .font(.niyaCaption2)
                                            .foregroundStyle(Color.niyaTeal)
                                    }
                                    Text(t.text)
                                        .font(.niyaCaption)
                                        .foregroundStyle(Color.niyaText)
                                        .lineLimit(2)
                                        .environment(\.layoutDirection, t.isRTL ? .rightToLeft : .leftToRight)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.niyaSecondary)
                }
                .listRowBackground(rowBackground(for: bookmark.bookmarkColor))
                .contentShape(Rectangle())
                .onTapGesture {
                    coordinator.navigateToAyah(surahId: bookmark.surahId, ayahId: bookmark.ayahId)
                    dismiss()
                }
                .contextMenu {
                    bookmarkContextMenu(
                        currentColor: bookmark.bookmarkColor,
                        setColor: { color in
                            stores.quranBookmarks.setColor(color, surahId: bookmark.surahId, ayahId: bookmark.ayahId)
                            reload()
                        },
                        remove: {
                            stores.quranBookmarks.toggle(surahId: bookmark.surahId, ayahId: bookmark.ayahId)
                            reload()
                        }
                    )
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        stores.quranBookmarks.toggle(surahId: bookmark.surahId, ayahId: bookmark.ayahId)
                        reload()
                    } label: {
                        Label("Remove", systemImage: "bookmark.slash")
                    }
                }
                .swipeActions(edge: .leading) {
                    colorSwipeButtons { color in
                        stores.quranBookmarks.setColor(color, surahId: bookmark.surahId, ayahId: bookmark.ayahId)
                        reload()
                    }
                }
            }
        } header: {
            sectionHeader("Qur'an")
        }
    }

    // MARK: - Hadith

    private var hadithSection: some View {
        ForEach(hadithGrouped, id: \.collection.id) { group in
            Section {
                ForEach(group.bookmarks, id: \.hadithKey) { bookmark in
                    if let hadith = hadithDataService.hadiths(for: bookmark.collectionId)
                        .first(where: { $0.id == bookmark.hadithId }) {
                        HStack(spacing: 8) {
                            HadithRowView(hadith: hadith, hasGrades: group.collection.hasGrades)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.niyaSecondary)
                        }
                        .listRowBackground(rowBackground(for: bookmark.bookmarkColor))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            coordinator.navigateToHadith(
                                collectionId: bookmark.collectionId,
                                hadithId: bookmark.hadithId,
                                hasGrades: group.collection.hasGrades
                            )
                            dismiss()
                        }
                        .contextMenu {
                            bookmarkContextMenu(
                                currentColor: bookmark.bookmarkColor,
                                setColor: { color in
                                    stores.hadithBookmarks.setColor(color, collectionId: bookmark.collectionId, hadithId: bookmark.hadithId)
                                    reload()
                                },
                                remove: {
                                    stores.hadithBookmarks.toggle(collectionId: bookmark.collectionId, hadithId: bookmark.hadithId)
                                    reload()
                                }
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                stores.hadithBookmarks.toggle(collectionId: bookmark.collectionId, hadithId: bookmark.hadithId)
                                reload()
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            colorSwipeButtons { color in
                                stores.hadithBookmarks.setColor(color, collectionId: bookmark.collectionId, hadithId: bookmark.hadithId)
                                reload()
                            }
                        }
                    }
                }
            } header: {
                if group.collection.id == hadithGrouped.first?.collection.id {
                    sectionHeader("Hadith")
                }
                Text(group.collection.name)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaSecondary)
            }
        }
    }

    // MARK: - Dua

    private var duaSection: some View {
        Section {
            ForEach(filteredDuaBookmarks, id: \.duaKey) { bookmark in
                if let dua = duaDataService.dua(categoryId: bookmark.categoryId, duaId: bookmark.duaId) {
                    let categoryName = duaDataService.category(id: bookmark.categoryId)?.name ?? "Dua"
                    let badgeColor = bookmark.bookmarkColor?.color ?? .niyaTeal

                    HStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "diamond")
                                .font(.system(size: 32))
                                .foregroundStyle(badgeColor.opacity(0.15))
                            Text("\(dua.number)")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(badgeColor)
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
                    .listRowBackground(rowBackground(for: bookmark.bookmarkColor))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.navigateToDua(categoryId: bookmark.categoryId, duaId: bookmark.duaId)
                        dismiss()
                    }
                    .contextMenu {
                        bookmarkContextMenu(
                            currentColor: bookmark.bookmarkColor,
                            setColor: { color in
                                stores.duaBookmarks.setColor(color, categoryId: bookmark.categoryId, duaId: bookmark.duaId)
                                reload()
                            },
                            remove: {
                                stores.duaBookmarks.toggle(categoryId: bookmark.categoryId, duaId: bookmark.duaId)
                                reload()
                            }
                        )
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            stores.duaBookmarks.toggle(categoryId: bookmark.categoryId, duaId: bookmark.duaId)
                            reload()
                        } label: {
                            Label("Remove", systemImage: "bookmark.slash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        colorSwipeButtons { color in
                            stores.duaBookmarks.setColor(color, categoryId: bookmark.categoryId, duaId: bookmark.duaId)
                            reload()
                        }
                    }
                }
            }
        } header: {
            sectionHeader("Dua")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func bookmarkContextMenu(
        currentColor: BookmarkColor?,
        setColor: @escaping (BookmarkColor?) -> Void,
        remove: @escaping () -> Void
    ) -> some View {
        Section("Color") {
            Button { setColor(nil) } label: {
                Label("Gold", systemImage: currentColor == nil ? "checkmark.circle.fill" : "circle.fill")
            }
            .tint(.niyaGold)
            ForEach(BookmarkColor.allCases) { bc in
                Button { setColor(bc) } label: {
                    Label(bc.displayName, systemImage: currentColor == bc ? "checkmark.circle.fill" : "circle.fill")
                }
                .tint(bc.color)
            }
        }
        Section {
            Button(role: .destructive, action: remove) {
                Label("Remove Bookmark", systemImage: "bookmark.slash")
            }
        }
    }

    // MARK: - Row Helpers

    private func rowBackground(for color: BookmarkColor?) -> some View {
        Group {
            if let color {
                color.color.opacity(0.08)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func colorSwipeButtons(setColor: @escaping (BookmarkColor?) -> Void) -> some View {
        Button { setColor(.emerald) } label: {
            Label("Emerald", systemImage: "circle.fill")
        }
        .tint(BookmarkColor.emerald.color)

        Button { setColor(.sapphire) } label: {
            Label("Sapphire", systemImage: "circle.fill")
        }
        .tint(BookmarkColor.sapphire.color)

        Button { setColor(.rose) } label: {
            Label("Rose", systemImage: "circle.fill")
        }
        .tint(BookmarkColor.rose.color)
    }

    // MARK: - Helpers

    private func buildTranslations(verse: Verse) -> [TranslationText] {
        let primaryRTL = quranDataService.selectedTranslations.first?.isRTL ?? false
        let primaryName = quranDataService.selectedTranslations.first?.name ?? "Translation"
        var result = [TranslationText(name: primaryName, text: verse.translation, isRTL: primaryRTL)]
        result.append(contentsOf: verse.extraTranslations)
        return result
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.niyaSubheadline)
            .foregroundStyle(Color.niyaText)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 4)
    }

    private func reload() {
        quranBookmarks = stores.quranBookmarks.allBookmarks()
        hadithBookmarks = stores.hadithBookmarks.allBookmarks()
        duaBookmarks = stores.duaBookmarks.allBookmarks()
    }

    private func loadHadithCollections() async {
        let bookmarks = stores.hadithBookmarks.allBookmarks()
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
