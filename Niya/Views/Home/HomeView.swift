import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.stores) private var stores
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @State private var positions: [ReadingPosition] = []
    @State private var recentHadiths: [RecentHadith] = []
    @State private var recentDuas: [RecentDua] = []
    @State private var loaded = false
    @State private var resolvedPositions: [(position: ReadingPosition, surah: Surah)] = []
    @State private var resolvedHadiths: [(recent: RecentHadith, hadith: Hadith, collection: HadithCollection)] = []
    @State private var resolvedDuas: [(recent: RecentDua, dua: Dua, categoryName: String)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if !loaded {
                    loadingPlaceholder
                        .transition(.opacity)
                } else if !resolvedPositions.isEmpty || !resolvedHadiths.isEmpty || !resolvedDuas.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        if !resolvedPositions.isEmpty {
                            continueReadingSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if !resolvedHadiths.isEmpty {
                            recentHadithSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if !resolvedDuas.isEmpty {
                            recentDuaSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.top, 16)
                } else {
                    emptyState
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.4), value: loaded)
            .animation(.easeOut(duration: 0.35), value: resolvedPositions.map(\.position.surahId))
            .animation(.easeOut(duration: 0.35), value: resolvedHadiths.map(\.recent.hadithKey))
            .animation(.easeOut(duration: 0.35), value: resolvedDuas.map(\.recent.duaKey))
            .background(Color.niyaBackground)
            .navigationTitle("Niya")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
        }
        .onAppear { reload() }
        .onChange(of: coordinator.selectedTab) { _, tab in
            if tab == .home { reload() }
        }
        .task {
            async let h: () = hadithDataService.load()
            async let d: () = duaDataService.load()
            _ = await (h, d)
            let recents = stores.recentHadith.recentHadiths()
            for id in Set(recents.map(\.collectionId)) {
                await hadithDataService.loadCollection(id)
            }
            reload()
            markLoaded()
        }
    }

    private func markLoaded() {
        guard !loaded else { return }
        loaded = true
    }

    private func reload() {
        positions = stores.readingPosition.recentPositions()
        recentHadiths = stores.recentHadith.recentHadiths()
        recentDuas = stores.recentDua.recentDuas()

        resolvedPositions = positions.compactMap { position in
            guard let surah = dataService.surahs.first(where: { $0.id == position.surahId }) else { return nil }
            return (position, surah)
        }
        resolvedHadiths = recentHadiths.compactMap { recent in
            guard let collection = hadithDataService.collections.first(where: { $0.id == recent.collectionId }),
                  let hadith = hadithDataService.hadiths(for: recent.collectionId).first(where: { $0.id == recent.hadithId })
            else { return nil }
            return (recent, hadith, collection)
        }
        resolvedDuas = recentDuas.compactMap { recent in
            guard let dua = duaDataService.dua(categoryId: recent.categoryId, duaId: recent.duaId) else { return nil }
            let categoryName = duaDataService.category(id: recent.categoryId)?.name ?? "Dua"
            return (recent, dua, categoryName)
        }
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionPlaceholder("Continue Reading")
            sectionPlaceholder("Recent Hadith")
            sectionPlaceholder("Recent Duas")
        }
        .padding(.top, 16)
    }

    private func sectionPlaceholder(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.niyaTitle)
                .foregroundStyle(Color.niyaText)
                .padding(.horizontal)

            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    // MARK: - Continue Reading

    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Reading")
                .font(.niyaTitle)
                .foregroundStyle(Color.niyaText)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(resolvedPositions, id: \.position.surahId) { item in
                        NavigationLink {
                            ReaderContainerView(
                                vm: ReaderViewModel(
                                    surah: item.surah,
                                    dataService: dataService,
                                    script: script,
                                    initialAyahId: item.position.lastAyahId
                                )
                            )
                        } label: {
                            ContinueReadingCard(surah: item.surah, position: item.position)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(item.position)
                                try? modelContext.save()
                                reload()
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Hadith

    private var recentHadithSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Hadith")
                .font(.niyaTitle)
                .foregroundStyle(Color.niyaText)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(resolvedHadiths, id: \.recent.hadithKey) { item in
                        Button {
                            coordinator.navigateToHadith(
                                collectionId: item.recent.collectionId,
                                hadithId: item.recent.hadithId,
                                hasGrades: item.recent.hasGrades
                            )
                        } label: {
                            RecentHadithCard(
                                hadith: item.hadith,
                                collectionName: item.collection.name,
                                visitedAt: item.recent.visitedAt
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(item.recent)
                                try? modelContext.save()
                                reload()
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Dua

    private var recentDuaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Duas")
                .font(.niyaTitle)
                .foregroundStyle(Color.niyaText)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(resolvedDuas, id: \.recent.duaKey) { item in
                        Button {
                            coordinator.navigateToDua(
                                categoryId: item.recent.categoryId,
                                duaId: item.recent.duaId
                            )
                        } label: {
                            RecentDuaCard(
                                dua: item.dua,
                                categoryName: item.categoryName,
                                visitedAt: item.recent.visitedAt
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(item.recent)
                                try? modelContext.save()
                                reload()
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(Color.niyaSecondary)
            Text("Start reading to see your progress here")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
