import SwiftUI

struct SurahListView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !isLoaded {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else {
                    surahList
                }
            }
            .navigationTitle("Quran")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
            .background(Color.niyaBackground)
            .navigationDestination(for: QuranNavDestination.self) { dest in
                if let surah = dataService.surahs.first(where: { $0.id == dest.surahId }) {
                    ReaderContainerView(
                        vm: ReaderViewModel(
                            surah: surah,
                            dataService: dataService,
                            script: script,
                            initialAyahId: dest.ayahId
                        )
                    )
                }
            }
        }
        .onChange(of: coordinator.pendingQuranDestination, initial: true) { _, newDest in
            if let dest = newDest {
                coordinator.pendingQuranDestination = nil
                path = NavigationPath()
                Task { @MainActor in
                    path.append(dest)
                }
            }
        }
        .task {
            await dataService.load()
            isLoaded = dataService.isLoaded
            loadError = dataService.loadError
        }
    }

    @ViewBuilder
    private var surahList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(dataService.surahs) { surah in
                    NavigationLink(value: QuranNavDestination(surahId: surah.id)) {
                        SurahRowView(surah: surah)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.horizontal)
                }
            }
        }
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
