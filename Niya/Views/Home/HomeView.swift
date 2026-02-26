import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var positions: [ReadingPosition] = []
    @State private var recentHadiths: [RecentHadith] = []
    @State private var recentDuas: [RecentDua] = []

    private var hasAny: Bool {
        !positions.isEmpty || !recentHadiths.isEmpty || !recentDuas.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if hasAny {
                    VStack(alignment: .leading, spacing: 20) {
                        if !positions.isEmpty {
                            continueReadingSection
                        }
                        if !recentHadiths.isEmpty {
                            recentHadithSection
                        }
                        if !recentDuas.isEmpty {
                            recentDuaSection
                        }
                    }
                    .padding(.top, 16)
                } else {
                    emptyState
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Niya")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
        }
        .onAppear { reload() }
        .task {
            await hadithDataService.load()
            let recents = RecentHadithStore(modelContext: modelContext).recentHadiths()
            for id in Set(recents.map(\.collectionId)) {
                await hadithDataService.loadCollection(id)
            }
            reload()
        }
        .task {
            await duaDataService.load()
            reload()
        }
    }

    private func reload() {
        positions = ReadingPositionStore(modelContext: modelContext).recentPositions()
        recentHadiths = RecentHadithStore(modelContext: modelContext).recentHadiths()
        recentDuas = RecentDuaStore(modelContext: modelContext).recentDuas()
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
                                        showTranslation: showTranslation,
                                        initialAyahId: position.lastAyahId
                                    )
                                )
                            } label: {
                                ContinueReadingCard(surah: surah, position: position)
                            }
                            .buttonStyle(.plain)
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
            Text("Recent Dua")
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
