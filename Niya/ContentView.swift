import SwiftUI

struct ContentView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        tabContent(selection: $coordinator.selectedTab)
            .tint(Color.niyaTeal)
            .overlay(alignment: .bottom) {
                if autoScrollVM.isEnabled {
                    AutoScrollBar()
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if audioPlayerVM.hasActiveSession {
                    AudioPlayerBar()
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: autoScrollVM.isEnabled)
            .animation(.spring(duration: 0.35), value: audioPlayerVM.hasActiveSession)
            .task {
                await dataService.load()
            }
            .task {
                await hadithDataService.load()
            }
            .task {
                await duaDataService.load()
            }
    }

    @ViewBuilder
    private func tabContent(selection: Binding<String>) -> some View {
        if #available(iOS 18.0, *) {
            let tv = TabView(selection: selection) {
                Tab("Home", systemImage: "house", value: "home") {
                    HomeView()
                }
                Tab("Quran", systemImage: "text.book.closed.fill", value: "quran") {
                    SurahListView()
                }
                Tab("Hadith", systemImage: "books.vertical.fill", value: "hadith") {
                    HadithTabView()
                }
                Tab("Dua", systemImage: "quote.bubble.fill", value: "dua") {
                    DuaTabView()
                }
                Tab("Search", systemImage: "magnifyingglass", value: "search", role: .search) {
                    SurahSearchView()
                }
            }
            if #available(iOS 26.0, *) {
                tv.tabBarMinimizeBehavior(.onScrollDown)
            } else {
                tv
            }
        } else {
            TabView(selection: selection) {
                HomeView().tabItem { Label("Home", systemImage: "house") }.tag("home")
                SurahListView().tabItem { Label("Quran", systemImage: "text.book.closed.fill") }.tag("quran")
                HadithTabView().tabItem { Label("Hadith", systemImage: "books.vertical.fill") }.tag("hadith")
                DuaTabView().tabItem { Label("Dua", systemImage: "quote.bubble.fill") }.tag("dua")
                SurahSearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }.tag("search")
            }
        }
    }
}
