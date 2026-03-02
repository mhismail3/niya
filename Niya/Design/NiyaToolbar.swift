import SwiftUI

struct NiyaToolbar: ViewModifier {
    @State private var showSettings = false
    @State private var showBookmarks = false
    @State private var showSalah = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showBookmarks = true } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Bookmarks")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSalah = true } label: {
                        Image(systemName: "location.circle")
                    }
                    .accessibilityLabel("Qibla and prayer times")
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
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showSalah) {
                SalahSheetView()
            }
    }
}

extension View {
    func niyaToolbar() -> some View {
        modifier(NiyaToolbar())
    }
}
