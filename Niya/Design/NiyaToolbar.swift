import SwiftUI

struct NiyaToolbar: ViewModifier {
    @State private var showSettings = false
    @State private var showBookmarks = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showBookmarks = true } label: {
                        Image(systemName: "bookmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
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
    }
}

extension View {
    func niyaToolbar() -> some View {
        modifier(NiyaToolbar())
    }
}
