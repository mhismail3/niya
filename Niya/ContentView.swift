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
        .tint(Color.niyaTeal)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay(alignment: .bottom) {
            if audioPlayerVM.hasActiveSession {
                AudioPlayerBar()
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: audioPlayerVM.hasActiveSession)
        .task {
            await dataService.load()
        }
        .onAppear {
            audioPlayerVM.setDownloadStore(DownloadStore(modelContext: modelContext))
        }
    }
}
