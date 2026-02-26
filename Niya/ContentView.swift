import SwiftUI

struct ContentView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var coordinator = coordinator
        TabView(selection: $coordinator.selectedTab) {
            Tab("Home", systemImage: "house", value: "home") {
                HomeView()
            }
            Tab("Quran", systemImage: "book.pages", value: "quran") {
                SurahListView()
            }
            Tab("Hadith", systemImage: "text.book.closed", value: "hadith") {
                HadithTabView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: "search", role: .search) {
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
        .task {
            await hadithDataService.load()
        }
        .onAppear {
            audioPlayerVM.setDownloadStore(DownloadStore(modelContext: modelContext))
        }
    }
}
