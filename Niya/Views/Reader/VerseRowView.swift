import SwiftUI

struct VerseRowView: View {
    let verse: Verse
    let surahId: Int
    let script: QuranScript
    let showTranslation: Bool
    let isPlaying: Bool
    let isBookmarked: Bool
    let onPlay: () -> Void
    let onBookmark: () -> Void
    @Environment(TajweedService.self) private var tajweedService
    @AppStorage("showTajweed") private var showTajweed: Bool = true
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @AppStorage("translationIsRTL") private var translationIsRTL: Bool = false
    @State private var tajweedActive = false
    @State private var activeTap: TajweedTap?
    @State private var tooltipWidth: CGFloat = 160
    @State private var dismissTask: Task<Void, Never>?

    private var tajweedAvailable: Bool { script == .hafs }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .center) {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(isPlaying ? Color.niyaGold : Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Button(action: onBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(isBookmarked ? Color.niyaGold : Color.niyaSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                verseNumberBadge
            }

            if (tajweedActive || showTajweed) && script == .hafs, let tv = tajweedService.verse(surahId: surahId, ayahId: verse.id) {
                TajweedTextView(verse: tv, fontSize: arabicFontSize) { tap in
                    handleTajweedTap(tap)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .overlay {
                    GeometryReader { geo in
                        if let tap = activeTap {
                            let halfW = tooltipWidth / 2
                            let clampedX = min(max(tap.position.x, halfW), geo.size.width - halfW)
                            tajweedTooltip(for: tap.rule)
                                .background {
                                    GeometryReader { tipGeo in
                                        Color.clear
                                            .onAppear { tooltipWidth = tipGeo.size.width }
                                            .onChange(of: tap.rule) { _, _ in
                                                tooltipWidth = tipGeo.size.width
                                            }
                                    }
                                }
                                .position(x: clampedX, y: tap.position.y - 24)
                        }
                    }
                }
                .transition(.opacity)
                .onScrollVisibilityChange { visible in
                    if !visible { dismissTooltip() }
                }
            } else {
                Text(verse.text)
                    .font(.quranText(script: script, size: arabicFontSize))
                    .foregroundStyle(Color.niyaText)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard tajweedAvailable else { return }
                        tajweedService.fetch(surahId: surahId)
                        withAnimation(.easeInOut(duration: 0.3)) { tajweedActive = true }
                    }
            }

            if showTranslation, !verse.translation.isEmpty {
                Text(verse.translation)
                    .font(.system(size: translationFontSize, design: .serif))
                    .foregroundStyle(Color.niyaSecondary)
                    .multilineTextAlignment(translationIsRTL ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: translationIsRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, translationIsRTL ? .rightToLeft : .leftToRight)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background {
            if isPlaying {
                Color.niyaGold.opacity(0.06)
                    .padding(.horizontal, -16)
            }
        }
        .onChange(of: showTajweed) { _, on in
            if !on {
                tajweedActive = false
                dismissTooltip()
            }
        }
    }

    private func handleTajweedTap(_ tap: TajweedTap?) {
        dismissTask?.cancel()

        guard let tap else {
            withAnimation(.easeOut(duration: 0.2)) { activeTap = nil }
            return
        }

        // Tap same region → dismiss
        if let current = activeTap, current.rule == tap.rule,
           abs(current.position.x - tap.position.x) < 20,
           abs(current.position.y - tap.position.y) < 20 {
            withAnimation(.easeOut(duration: 0.2)) { activeTap = nil }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) { activeTap = tap }

        // Auto-dismiss after 5 seconds
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { activeTap = nil }
        }
    }

    private func dismissTooltip() {
        dismissTask?.cancel()
        activeTap = nil
    }

    private func tajweedTooltip(for rule: TajweedRule) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(rule.color)
                .frame(width: 10, height: 10)
            Text(rule.displayName)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
            Text(rule.arabicName)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.niyaSurface, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .fixedSize()
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    private var verseNumberBadge: some View {
        ZStack {
            Image(systemName: "diamond")
                .font(.system(size: 24))
                .foregroundStyle(Color.niyaTeal.opacity(0.15))
            Text("\(verse.id)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
        }
    }
}
