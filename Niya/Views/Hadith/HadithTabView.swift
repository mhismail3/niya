import SwiftUI

struct HadithTabView: View {
    @Environment(HadithDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var path = NavigationPath()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if dataService.isLoaded {
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
                } else if let error = dataService.loadError {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Hadith")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
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
    }
}
