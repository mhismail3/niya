import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @State private var positions: [ReadingPosition] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if positions.isEmpty {
                        emptyState
                    } else {
                        continueReadingSection
                    }
                }
                .padding(.top, 16)
            }
            .background(Color.niyaBackground)
            .navigationTitle("Niya")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
        }
        .onAppear {
            positions = ReadingPositionStore(modelContext: modelContext).recentPositions()
        }
    }

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
