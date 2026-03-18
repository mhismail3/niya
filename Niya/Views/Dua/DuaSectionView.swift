import SwiftUI

struct DuaSectionView: View {
    let section: DuaSection
    @Environment(DuaDataService.self) private var dataService

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(dataService.categories(for: section.id)) { category in
                    let duas = dataService.duas(for: category.id)
                    if !duas.isEmpty {
                        Text(category.name)
                            .font(.niyaSubheadline)
                            .foregroundStyle(Color.niyaSecondary)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 6)

                        ForEach(Array(duas.enumerated()), id: \.element.id) { index, dua in
                            NavigationLink(value: DuaNavDestination(categoryId: category.id, duaId: dua.id)) {
                                DuaRowView(dua: dua, index: index + 1)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }
        }
        .background(Color.niyaBackground)
        .navigationTitle(section.name)
        .navigationBarTitleDisplayMode(.large)
        .niyaToolbar(showSalahButton: false)
    }
}
