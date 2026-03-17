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
                ToolbarItem(placement: .topBarLeading) {
                    Button { showBookmarks = true } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Bookmarks")
                }
                if showSalahButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { coordinator.showSalahSheet = true } label: {
                            Image(systemName: "location.circle")
                        }
                        .accessibilityLabel("Qibla and prayer times")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
