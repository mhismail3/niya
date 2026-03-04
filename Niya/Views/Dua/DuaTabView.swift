import SwiftUI

struct DuaTabView: View {
    @Environment(DuaDataService.self) private var dataService
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var path = NavigationPath()

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
            .navigationDestination(for: DuaSection.self) { section in
                DuaSectionView(section: section)
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
                Task { @MainActor in
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
            LazyVStack(spacing: 0) {
                ForEach(dataService.sections) { section in
                    NavigationLink(value: section) {
                        DuaSectionRow(section: section, totalDuas: dataService.totalDuas(for: section.id))
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

private struct DuaSectionRow: View {
    let section: DuaSection
    let totalDuas: Int

    var body: some View {
        HStack {
            Text(section.name)
                .font(.niyaBody)
                .foregroundStyle(Color.niyaText)

            Spacer()

            Text("\(totalDuas)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.niyaTeal.opacity(0.12))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.niyaSecondary)
        }
    }
}
