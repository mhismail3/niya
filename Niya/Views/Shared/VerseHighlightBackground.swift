import SwiftUI

/// Leaf view that owns the highlight environment read + animation, so environment changes
/// only invalidate this small subtree — not the full VerseRowView / FollowAlongVerseView body,
/// which would otherwise retrigger expensive TajweedTextView reconfiguration.
struct VerseHighlightBackground: View {
    let verseId: Int
    let isPlaying: Bool
    @Environment(\.highlightedAyahId) private var highlightedAyahId

    var body: some View {
        Group {
            if isPlaying {
                Color.niyaGold.opacity(0.06)
                    .padding(.horizontal, -16)
            } else if highlightedAyahId == verseId {
                Color.niyaGold.opacity(0.15)
                    .padding(.horizontal, -16)
            }
        }
        .animation(.easeOut(duration: 0.5), value: highlightedAyahId)
    }
}
