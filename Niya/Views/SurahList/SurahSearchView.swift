import SwiftUI

struct SurahSearchView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(\.stores) private var stores
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @State private var searchQuery = ""
    @State private var recentQueries: [RecentSearch] = []
    @State private var surahResults: [Surah] = []
    @State private var hadithResults: [HadithSearchItem] = []
    @State private var duaResults: [DuaSearchItem] = []
    @State private var searchTask: Task<Void, Never>?

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    unifiedSearchResults
                } else {
                    recentsList
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
        }
        .searchable(text: $searchQuery, prompt: "Surahs, hadiths, and duas")
        .onChange(of: searchQuery) { _, newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                surahResults = []
                hadithResults = []
                duaResults = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                updateSearch()
            }
        }
        .onSubmit(of: .search) {
            stores.recentSearch.saveQuery(searchQuery)
            reloadRecents()
        }
        .onAppear { reloadRecents() }
    }

    // MARK: - Unified Search

    private var unifiedSearchResults: some View {
        let hasAny = !surahResults.isEmpty || !hadithResults.isEmpty || !duaResults.isEmpty

        return List {
            if !surahResults.isEmpty {
                Section {
                    ForEach(surahResults) { surah in
                        NavigationLink(destination: readerView(for: surah)) {
                            SurahRowView(surah: surah)
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Quran", count: surahResults.count)
                }
            }

            if !hadithResults.isEmpty {
                Section {
                    ForEach(hadithResults) { item in
                        let collection = hadithDataService.collections.first { $0.id == item.collectionId }
                        NavigationLink {
                            HadithDetailView(
                                hadith: item.hadith,
                                collectionId: item.collectionId,
                                hasGrades: collection?.hasGrades ?? false
                            )
                        } label: {
                            HadithSearchResultRow(
                                collectionId: item.collectionId,
                                hadith: item.hadith,
                                collectionName: collection?.name ?? item.collectionId,
                                hasGrades: collection?.hasGrades ?? false
                            )
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Hadith", count: hadithResults.count)
                }
            }

            if !duaResults.isEmpty {
                Section {
                    ForEach(duaResults) { item in
                        let category = duaDataService.category(id: item.categoryId)
                        NavigationLink {
                            DuaDetailView(dua: item.dua, categoryId: item.categoryId)
                        } label: {
                            DuaSearchResultRow(
                                categoryName: category?.name ?? "Dua",
                                dua: item.dua
                            )
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Dua", count: duaResults.count)
                }
            }

            if !hasAny {
                ContentUnavailableView.search(text: searchQuery)
                    .listRowBackground(Color.niyaBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
            Spacer()
            Text("\(count)")
                .font(.niyaCaption2)
                .foregroundStyle(Color.niyaSecondary)
        }
    }

    // MARK: - Recents & Suggestions

    private let suggestedTerms = [
        "Al-Fatiha", "Al-Baqarah", "Yasin", "Al-Mulk", "Ar-Rahman",
        "Ayat al-Kursi", "patience", "mercy", "forgiveness", "paradise",
        "prayer", "fasting", "charity", "repentance", "gratitude",
        "الفاتحة", "يس", "الملك", "الرحمن", "الكهف",
        "صبر", "رحمة", "توبة", "دعاء", "جنة",
    ]

    private var recentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !recentQueries.isEmpty {
                    sectionHeader("Recent Searches")
                    ForEach(recentQueries, id: \.id) { recent in
                        Button {
                            searchQuery = recent.query
                        } label: {
                            Label(recent.query, systemImage: "magnifyingglass")
                                .font(.niyaBody)
                                .foregroundStyle(Color.niyaText)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider().padding(.horizontal)
                    }
                }

                sectionHeader("Suggested")
                FlowLayout(spacing: 8, rightToLeft: false) {
                    ForEach(suggestedTerms, id: \.self) { term in
                        Button {
                            searchQuery = term
                        } label: {
                            Text(term)
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.niyaSurface, in: .capsule)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.niyaCaption)
            .foregroundStyle(Color.niyaSecondary)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private func readerView(for surah: Surah) -> some View {
        ReaderContainerView(
            vm: ReaderViewModel(
                surah: surah,
                dataService: dataService,
                script: script
            )
        )
    }

    private func updateSearch() {
        surahResults = dataService.searchSurahs(query: searchQuery)
        hadithResults = hadithDataService.searchHadiths(query: searchQuery).map {
            HadithSearchItem(collectionId: $0.collectionId, hadith: $0.hadith)
        }
        duaResults = duaDataService.searchDuas(query: searchQuery).map {
            DuaSearchItem(categoryId: $0.categoryId, dua: $0.dua)
        }
    }

    private func reloadRecents() {
        recentQueries = stores.recentSearch.recentQueries()
    }
}

private struct HadithSearchItem: Identifiable {
    let id: String
    let collectionId: String
    let hadith: Hadith

    init(collectionId: String, hadith: Hadith) {
        self.id = "\(collectionId):\(hadith.id)"
        self.collectionId = collectionId
        self.hadith = hadith
    }
}

private struct DuaSearchItem: Identifiable {
    let id: String
    let categoryId: String
    let dua: Dua

    init(categoryId: String, dua: Dua) {
        self.id = "\(categoryId):\(dua.id)"
        self.categoryId = categoryId
        self.dua = dua
    }
}
