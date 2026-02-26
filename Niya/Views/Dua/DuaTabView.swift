import SwiftUI

struct DuaTabView: View {
    @Environment(DuaDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var path = NavigationPath()
    @State private var expandedSections: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !isLoaded {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else {
                    sectionList
                }
            }
            .navigationTitle("Dua")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
            .background(Color.niyaBackground)
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
        .task {
            await dataService.load()
            isLoaded = dataService.isLoaded
            loadError = dataService.loadError
        }
    }

    @ViewBuilder
    private var sectionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(dataService.sections) { section in
                    sectionView(section)
                }
            }
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
                        .font(.niyaBody)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(cats) { category in
                    NavigationLink(value: category) {
                        DuaCategoryRow(category: category)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 32)
                }
            }

            Divider().padding(.horizontal)
        }
    }
}
