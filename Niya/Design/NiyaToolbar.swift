import SwiftUI

struct NiyaToolbar: ViewModifier {
    var showSalahButton = true
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var showSettings = false
    @State private var showBookmarks = false

    func body(content: Content) -> some View {
        @Bindable var coord = coordinator
        content
            .toolbar {
                if showSalahButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { coordinator.showSalahSheet = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "location.circle")
                                Text("Prayer Times")
                                    .font(.niyaControlLabel)
                            }
                        }
                        .accessibilityLabel("Prayer Times")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showBookmarks = true } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Bookmarks")

                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showBookmarks) {
                BookmarksView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $coord.showSalahSheet) {
                SalahSheetView()
            }
    }
}

extension View {
    func niyaToolbar(showSalahButton: Bool = true) -> some View {
        modifier(NiyaToolbar(showSalahButton: showSalahButton))
    }
}
