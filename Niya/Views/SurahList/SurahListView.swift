import SwiftUI

struct SurahListView: View {
    @Environment(QuranDataService.self) private var dataService
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var isLoaded = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if !isLoaded {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else {
                    surahList
                }
            }
            .navigationTitle("Qur'an")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.niyaBackground)
        }
        .task {
            await dataService.load()
            isLoaded = dataService.isLoaded
            loadError = dataService.loadError
        }
    }

    @ViewBuilder
    private var surahList: some View {
        List(dataService.surahs) { surah in
            NavigationLink(destination: readerView(for: surah)) {
                SurahRowView(surah: surah)
            }
            .listRowBackground(Color.niyaBackground)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.niyaBackground)
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.niyaGold)
            Text("Loading Quran…")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.niyaBackground)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.niyaGold)
            Text("Failed to load: \(message)")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.niyaText)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.niyaBackground)
    }
}
