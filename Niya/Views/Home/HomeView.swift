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

    var body: some View {
        NavigationStack {
            ScrollView {
                if !loaded {
                    loadingPlaceholder
                        .transition(.opacity)
                } else if !positions.isEmpty || !recentHadiths.isEmpty || !recentDuas.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        if !positions.isEmpty {
                            continueReadingSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if !recentHadiths.isEmpty {
                            recentHadithSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if !recentDuas.isEmpty {
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
            .animation(.easeOut(duration: 0.35), value: positions.map(\.surahId))
            .animation(.easeOut(duration: 0.35), value: recentHadiths.map(\.hadithKey))
            .animation(.easeOut(duration: 0.35), value: recentDuas.map(\.duaKey))
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
            recentHadiths = stores.recentHadith.recentHadiths()
            recentDuas = stores.recentDua.recentDuas()
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
                    ForEach(positions, id: \.surahId) { position in
                        if let surah = dataService.surahs.first(where: { $0.id == position.surahId }) {
                            NavigationLink {
                                ReaderContainerView(
                                    vm: ReaderViewModel(
                                        surah: surah,
                                        dataService: dataService,
                                        script: script,
                                        initialAyahId: position.lastAyahId
                                    )
                                )
                            } label: {
                                ContinueReadingCard(surah: surah, position: position)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(position)
                                    try? modelContext.save()
                                    reload()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.red)
                            }
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
                    ForEach(recentHadiths, id: \.hadithKey) { recent in
                        let collection = hadithDataService.collections.first { $0.id == recent.collectionId }
                        let hadith = hadithDataService.hadiths(for: recent.collectionId)
                            .first { $0.id == recent.hadithId }

                        if let hadith, let collection {
                            Button {
                                coordinator.navigateToHadith(
                                    collectionId: recent.collectionId,
                                    hadithId: recent.hadithId,
                                    hasGrades: recent.hasGrades
                                )
                            } label: {
                                RecentHadithCard(
                                    hadith: hadith,
                                    collectionName: collection.name,
                                    visitedAt: recent.visitedAt
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(recent)
                                    try? modelContext.save()
                                    reload()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.red)
                            }
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
                    ForEach(recentDuas, id: \.duaKey) { recent in
                        let dua = duaDataService.dua(categoryId: recent.categoryId, duaId: recent.duaId)
                        let categoryName = duaDataService.category(id: recent.categoryId)?.name ?? "Dua"

                        if let dua {
                            Button {
                                coordinator.navigateToDua(
                                    categoryId: recent.categoryId,
                                    duaId: recent.duaId
                                )
                            } label: {
                                RecentDuaCard(
                                    dua: dua,
                                    categoryName: categoryName,
                                    visitedAt: recent.visitedAt
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(recent)
                                    try? modelContext.save()
                                    reload()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.red)
                            }
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
