import SwiftUI

struct HadithChapterView: View {
    let collectionId: String
    let chapter: HadithChapter
    let hasGrades: Bool
    @Environment(HadithDataService.self) private var dataService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(dataService.hadiths(for: collectionId, chapterId: chapter.id)) { hadith in
                    NavigationLink(value: HadithNavDestination(collectionId: collectionId, hadithId: hadith.id, hasGrades: hasGrades)) {
                        HadithRowView(hadith: hadith, hasGrades: hasGrades)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.horizontal)
                }
            }
        }
        .background(Color.niyaBackground)
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.large)
        .niyaToolbar()
    }
}
