import SwiftUI

struct DuaTabView: View {
    @Environment(DuaDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var path = NavigationPath()
    @State private var expandedSections: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if dataService.isLoaded {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(dataService.sections) { section in
                            sectionView(section)
                        }
                    }
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
            .navigationTitle("Dua")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
            .navigationDestination(for: DuaCategory.self) { category in
                DuaCategoryView(category: category)
            }
            .navigationDestination(for: DuaNavDestination.self) { dest in
                if let dua = dataService.dua(categoryId: dest.categoryId, duaId: dest.duaId) {
                    DuaDetailView(dua: dua, categoryId: dest.categoryId)
                }
            }
        }
        .onChange(of: coordinator.pendingDuaDestination, initial: true) { _, newDest in
            if let dest = newDest {
                coordinator.pendingDuaDestination = nil
                path = NavigationPath()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    path.append(dest)
                }
            }
        }
    }

    private func sectionView(_ section: DuaSection) -> some View {
        let isExpanded = expandedSections.contains(section.id)
        let cats = dataService.categories(for: section.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedSections.remove(section.id)
                    } else {
                        expandedSections.insert(section.id)
                    }
                }
            } label: {
                HStack {
                    Text(section.name)
                        .font(.niyaSubheadline)
                        .foregroundStyle(Color.niyaText)

                    Spacer()

                    Text("\(cats.count)")
                        .font(.niyaCaption2)
                        .foregroundStyle(Color.niyaSecondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.niyaSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(cats) { category in
                    NavigationLink(value: category) {
                        DuaCategoryRow(category: category)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 32)
                }
            }

            Divider().padding(.horizontal)
        }
    }
}
