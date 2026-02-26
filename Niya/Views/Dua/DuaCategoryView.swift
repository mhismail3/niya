import SwiftUI

struct DuaCategoryView: View {
    let category: DuaCategory
    @Environment(DuaDataService.self) private var dataService

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(dataService.duas(for: category.id)) { dua in
                    NavigationLink(value: DuaNavDestination(categoryId: category.id, duaId: dua.id)) {
                        DuaRowView(dua: dua)
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
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .niyaToolbar()
    }
}
