import SwiftUI

struct SurahSearchView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var searchQuery = ""
    @State private var recentQueries: [RecentSearch] = []
    @State private var recentSurahs: [RecentSearch] = []
    @State private var showSettings = false

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchResults
                } else {
                    recentsList
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .searchable(text: $searchQuery, prompt: "Surah name or number")
        .onSubmit(of: .search) {
            let store = RecentSearchStore(modelContext: modelContext)
            store.saveQuery(searchQuery)
            reloadRecents()
        }
        .onAppear { reloadRecents() }
    }

    private var searchResults: some View {
        List(dataService.searchSurahs(query: searchQuery)) { surah in
            NavigationLink(destination: readerView(for: surah)) {
                SurahRowView(surah: surah)
            }
            .listRowBackground(Color.niyaBackground)
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
