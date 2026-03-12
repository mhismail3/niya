import SwiftUI

struct ContentView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(AutoScrollViewModel.self) private var autoScrollVM
    @Environment(NavigationCoordinator.self) private var coordinator

    private var barChromeHidden: Bool {
        coordinator.isChromeHidden && coordinator.isReaderVisible
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        tabContent(selection: $coordinator.selectedTab)
            .tint(Color.niyaTeal)
            .overlay(alignment: .bottom) {
                if autoScrollVM.isEnabled {
                    AutoScrollBar()
                        .padding(.bottom, barChromeHidden ? 0 : 60)
                        .animation(.easeInOut(duration: 0.3), value: barChromeHidden)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if audioPlayerVM.hasActiveSession {
                    AudioPlayerBar()
                        .padding(.bottom, barChromeHidden ? 0 : 60)
                        .animation(.easeInOut(duration: 0.3), value: barChromeHidden)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: autoScrollVM.isEnabled)
            .animation(.spring(duration: 0.35), value: audioPlayerVM.hasActiveSession)
            .task {
                async let d: () = dataService.load()
                async let h: () = hadithDataService.load()
                async let du: () = duaDataService.load()
                _ = await (d, h, du)
            }
    }

    @ViewBuilder
    private func tabContent(selection: Binding<AppTab>) -> some View {
        if #available(iOS 18.0, *) {
            let tv = TabView(selection: selection) {
                Tab("Home", systemImage: "house", value: AppTab.home) {
                    HomeView()
                }
                Tab("Quran", systemImage: "text.book.closed.fill", value: AppTab.quran) {
                    SurahListView()
                }
                Tab("Hadith", systemImage: "books.vertical.fill", value: AppTab.hadith) {
                    HadithTabView()
                }
                Tab("Dua", systemImage: "quote.bubble.fill", value: AppTab.dua) {
                    DuaTabView()
                }
                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
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
                HomeView().tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)
                SurahListView().tabItem { Label("Quran", systemImage: "text.book.closed.fill") }.tag(AppTab.quran)
                HadithTabView().tabItem { Label("Hadith", systemImage: "books.vertical.fill") }.tag(AppTab.hadith)
                DuaTabView().tabItem { Label("Dua", systemImage: "quote.bubble.fill") }.tag(AppTab.dua)
                SurahSearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(AppTab.search)
            }
        }
    }
}
