import SwiftUI

struct HadithCollectionView: View {
    let collection: HadithCollection
    @Environment(HadithDataService.self) private var dataService
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(dataService.chapters(for: collection.id)) { chapter in
                            NavigationLink(value: ChapterDestination(collectionId: collection.id, chapter: chapter)) {
                                HadithChapterRow(chapter: chapter)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }
        }
        .background(Color.niyaBackground)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
        .niyaToolbar()
        .navigationDestination(for: ChapterDestination.self) { dest in
            HadithChapterView(collectionId: dest.collectionId, chapter: dest.chapter, hasGrades: collection.hasGrades)
        }
        .task {
            await dataService.loadCollection(collection.id)
            isLoading = false
        }
    }
}

struct ChapterDestination: Hashable, Sendable {
    let collectionId: String
    let chapter: HadithChapter
}
