import SwiftUI

struct HadithTabView: View {
    @Environment(HadithDataService.self) private var dataService

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
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
        }
    }
}
