import SwiftUI

struct HadithTabView: View {
    @Environment(HadithDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var path = NavigationPath()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !isLoaded {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else {
                    collectionGrid
                }
            }
            .navigationTitle("Hadith")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
            .background(Color.niyaBackground)
            .navigationDestination(for: HadithCollection.self) { collection in
                HadithCollectionView(collection: collection)
            }
            .navigationDestination(for: ChapterDestination.self) { dest in
                HadithChapterView(collectionId: dest.collectionId, chapter: dest.chapter, hasGrades: dest.hasGrades)
            }
            .navigationDestination(for: HadithNavDestination.self) { dest in
                if let hadith = dataService.hadiths(for: dest.collectionId).first(where: { $0.id == dest.hadithId }) {
                    HadithDetailView(hadith: hadith, collectionId: dest.collectionId, hasGrades: dest.hasGrades)
                }
            }
        }
        .onChange(of: coordinator.pendingHadithDestination, initial: true) { _, newDest in
            if let dest = newDest {
                coordinator.pendingHadithDestination = nil
                path = NavigationPath()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
    private var collectionGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(dataService.collections) { collection in
                    NavigationLink(value: collection) {
                        HadithCollectionCard(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var loadingView: some View {
        ProgressView()
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
