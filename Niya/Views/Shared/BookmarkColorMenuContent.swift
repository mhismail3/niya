import SwiftUI

struct BookmarkColorMenuContent: View {
    let currentColor: BookmarkColor?
    let onSetColor: (BookmarkColor?) -> Void
    let onRemove: () -> Void

    var body: some View {
        Section("Color") {
            Button { onSetColor(nil) } label: {
                Label("Gold", systemImage: currentColor == nil ? "checkmark.circle.fill" : "circle.fill")
            }
            .tint(.niyaGold)
            ForEach(BookmarkColor.allCases) { bc in
                Button { onSetColor(bc) } label: {
                    Label(bc.displayName, systemImage: currentColor == bc ? "checkmark.circle.fill" : "circle.fill")
                }
                .tint(bc.color)
            }
        }
        Section {
            Button(role: .destructive, action: onRemove) {
                Label("Remove Bookmark", systemImage: "bookmark.slash")
            }
        }
    }
}
