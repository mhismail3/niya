import SwiftUI

struct SurahSearchView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var searchQuery = ""
    @State private var recentQueries: [RecentSearch] = []

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
        .onSubmit(of: .search) {
            let store = RecentSearchStore(modelContext: modelContext)
            store.saveQuery(searchQuery)
            reloadRecents()
        }
        .onAppear { reloadRecents() }
    }

    // MARK: - Unified Search

    private var unifiedSearchResults: some View {
        let surahResults = dataService.searchSurahs(query: searchQuery)
        let hadithResults = hadithDataService.searchHadiths(query: searchQuery)
        let duaResults = duaDataService.searchDuas(query: searchQuery)
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
                    ForEach(Array(hadithResults.enumerated()), id: \.offset) { _, result in
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
                    sectionLabel("Hadith", count: hadithResults.count)
                }
            }

            if !duaResults.isEmpty {
                Section {
                    ForEach(Array(duaResults.enumerated()), id: \.offset) { _, result in
                        let category = duaDataService.category(id: result.categoryId)
                        NavigationLink {
                            DuaDetailView(dua: result.dua, categoryId: result.categoryId)
                        } label: {
                            DuaSearchResultRow(
                                categoryName: category?.name ?? "Dua",
                                dua: result.dua
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
                script: script,
                showTranslation: showTranslation
            )
        )
    }

    private func reloadRecents() {
        let store = RecentSearchStore(modelContext: modelContext)
        recentQueries = store.recentQueries()
    }
}
