import SwiftUI

struct ContentView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Quran", systemImage: "book.pages") {
                SurahListView()
            }
            Tab(role: .search) {
                SurahSearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay(alignment: .bottom) {
            if audioPlayerVM.isPlaying || audioPlayerVM.isLoading {
                AudioPlayerBar()
                    .padding(.bottom, 80)
            }
        }
        .task {
            await dataService.load()
        }
        .onAppear {
            audioPlayerVM.setDownloadStore(DownloadStore(modelContext: modelContext))
        }
    }
}
