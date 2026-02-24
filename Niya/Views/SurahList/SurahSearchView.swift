import SwiftUI

struct SurahSearchView: View {
    @Environment(QuranDataService.self) private var dataService
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            List(dataService.searchSurahs(query: searchQuery)) { surah in
                NavigationLink(destination: readerView(for: surah)) {
                    SurahRowView(surah: surah)
                }
                .listRowBackground(Color.niyaBackground)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.niyaBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(text: $searchQuery, prompt: "Surah name or number")
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
}
