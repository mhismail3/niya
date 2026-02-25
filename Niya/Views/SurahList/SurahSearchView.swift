import SwiftUI

enum SearchScope: String, CaseIterable {
    case quran = "Quran"
    case hadith = "Hadith"
}

struct SurahSearchView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var searchQuery = ""
    @State private var searchScope: SearchScope = .quran
    @State private var recentQueries: [RecentSearch] = []
    @State private var recentSurahs: [RecentSearch] = []

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    switch searchScope {
                    case .quran:
                        quranSearchResults
                    case .hadith:
                        hadithSearchResults
                    }
                } else {
                    recentsList
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
        }
        .searchable(text: $searchQuery, prompt: searchScope == .quran ? "Surah name or number" : "Search hadiths")
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .onSubmit(of: .search) {
            if searchScope == .quran {
                let store = RecentSearchStore(modelContext: modelContext)
                store.saveQuery(searchQuery)
                reloadRecents()
            }
        }
        .onAppear { reloadRecents() }
    }

    private var quranSearchResults: some View {
        List(dataService.searchSurahs(query: searchQuery)) { surah in
            NavigationLink(destination: readerView(for: surah)) {
                SurahRowView(surah: surah)
            }
            .listRowBackground(Color.niyaBackground)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var hadithSearchResults: some View {
        let results = hadithDataService.searchHadiths(query: searchQuery)
        return List {
            if hadithDataService.loadedCollectionCount > 0 {
                Section {
                    ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                        let collection = hadithDataService.collections.first { $0.id == result.collectionId }
                        NavigationLink {
                            HadithDetailView(
                                hadith: result.hadith,
                                collectionId: result.collectionId,
                                hasGrades: collection?.hasGrades ?? false
                            )
                        } label: {
                            HadithSearchResultRow(
                                collectionId: result.collectionId,
                                hadith: result.hadith,
                                collectionName: collection?.name ?? result.collectionId,
                                hasGrades: collection?.hasGrades ?? false
                            )
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    Text("Searching \(hadithDataService.loadedCollectionCount) loaded collections")
                        .font(.niyaCaption2)
                }
            } else {
                ContentUnavailableView(
                    "No Collections Loaded",
                    systemImage: "text.book.closed",
                    description: Text("Open a hadith collection first to search its contents")
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

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

                if !recentSurahs.isEmpty {
                    sectionHeader("Recently Opened")
                    ForEach(recentSurahs, id: \.id) { recent in
                        if let surahId = recent.surahId,
                           let surah = dataService.surahs.first(where: { $0.id == surahId }) {
                            NavigationLink(destination: readerView(for: surah)) {
                                SurahRowView(surah: surah)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                            }
                            Divider().padding(.horizontal)
                        }
                    }
                }

                if recentSurahs.isEmpty && recentQueries.isEmpty {
                    ContentUnavailableView(
                        "No Recent Searches",
                        systemImage: "magnifyingglass",
                        description: Text("Search for a surah by name or number")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
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
        let store = RecentSearchStore(modelContext: modelContext)
        store.saveSurah(surah.id, name: surah.transliteration)
        return ReaderContainerView(
            vm: ReaderViewModel(
                surah: surah,
                dataService: dataService,
                script: script,
                showTranslation: showTranslation
            )
        )
    }

    private func reloadRecents() {
        let store = RecentSearchStore(modelContext: modelContext)
        recentQueries = store.recentQueries()
        recentSurahs = store.recentSurahs()
    }
}
