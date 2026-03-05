import SwiftUI

struct DuaDetailView: View {
    let dua: Dua
    let categoryId: Int
    @Environment(DuaDataService.self) private var dataService
    @Environment(\.stores) private var stores
    @AppStorage(StorageKey.hadithArabicFontSize) private var arabicFontSize: Double = 22
    @AppStorage(StorageKey.translationFontSize) private var translationFontSize: Double = 16
    @State private var isBookmarked = false
    @State private var bookmarkColor: BookmarkColor?

    private var categoryName: String {
        dataService.category(id: categoryId)?.name ?? "Dua"
    }

    private var shareText: String {
        var parts = [dua.arabic]
        if let transliteration = dua.transliteration {
            parts.append(transliteration)
        }
        parts.append("")
        parts.append(dua.translation)
        parts.append("")
        parts.append(categoryName)
        if let source = dua.source {
            parts.append(source)
        }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                repeatBadge

                Text(dua.arabic)
                    .font(.custom("NotoNaskhArabic", size: arabicFontSize))
                    .foregroundStyle(Color.niyaText)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let transliteration = dua.transliteration {
                    Text(transliteration)
                        .font(.system(size: translationFontSize - 2, design: .serif))
                        .italic()
                        .foregroundStyle(Color.niyaSecondary)
                }

                Divider()

                Text(dua.translation)
                    .font(.system(size: translationFontSize, design: .serif))
                    .foregroundStyle(Color.niyaText)
                    .lineSpacing(4)

                if let benefits = dua.benefits {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Benefits")
                            .font(.niyaCaption)
                            .foregroundStyle(Color.niyaGold)
                        Text(benefits)
                            .font(.system(size: translationFontSize - 2, design: .serif))
                            .foregroundStyle(Color.niyaSecondary)
                            .lineSpacing(3)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    metadataRow("Category", value: categoryName)
                    if let source = dua.source {
                        metadataRow("Source", value: source)
                    }
                }

                actionBar
            }
            .padding()
        }
        .background(Color.niyaBackground)
        .navigationBarTitleDisplayMode(.inline)
        .niyaToolbar()
        .onAppear {
            isBookmarked = stores.duaBookmarks.isBookmarked(categoryId: categoryId, duaId: dua.id)
            if isBookmarked {
                bookmarkColor = stores.duaBookmarks.allBookmarks()
                    .first { $0.categoryId == categoryId && $0.duaId == dua.id }?.bookmarkColor
            }
            stores.recentDua
                .record(categoryId: categoryId, duaId: dua.id)
        }
    }

    @ViewBuilder
    private var repeatBadge: some View {
        if let rep = dua.repeat, rep > 1 {
            Text("Recite \(rep)x")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.niyaTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.niyaTeal.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 24) {
            Button {
                stores.duaBookmarks.toggle(categoryId: categoryId, duaId: dua.id)
                isBookmarked.toggle()
                if !isBookmarked { bookmarkColor = nil }
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.niyaVerseAction)
                    .foregroundStyle(isBookmarked ? (bookmarkColor?.color ?? .niyaGold) : Color.niyaSecondary)
            }
            .accessibilityLabel(isBookmarked ? "Remove bookmark, \(bookmarkColor?.displayName ?? "Gold")" : "Add bookmark")
            .contextMenu {
                if isBookmarked {
                    Section("Color") {
                        Button { setDuaBookmarkColor(nil) } label: {
                            Label("Gold", systemImage: bookmarkColor == nil ? "checkmark.circle.fill" : "circle.fill")
                        }
                        .tint(.niyaGold)
                        ForEach(BookmarkColor.allCases) { bc in
                            Button { setDuaBookmarkColor(bc) } label: {
                                Label(bc.displayName, systemImage: bookmarkColor == bc ? "checkmark.circle.fill" : "circle.fill")
                            }
                            .tint(bc.color)
                        }
                    }
                    Section {
                        Button(role: .destructive) {
                            stores.duaBookmarks.toggle(categoryId: categoryId, duaId: dua.id)
                            isBookmarked = false
                            bookmarkColor = nil
                        } label: {
                            Label("Remove Bookmark", systemImage: "bookmark.slash")
                        }
                    }
                }
            }

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.niyaVerseAction)
                    .foregroundStyle(Color.niyaSecondary)
            }
            .accessibilityLabel("Share dua")

            Button {
                UIPasteboard.general.string = shareText
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.niyaVerseAction)
                    .foregroundStyle(Color.niyaSecondary)
            }
            .accessibilityLabel("Copy dua text")

            Spacer()
        }
        .padding(.top, 8)
    }

    private func setDuaBookmarkColor(_ color: BookmarkColor?) {
        stores.duaBookmarks.setColor(color, categoryId: categoryId, duaId: dua.id)
        bookmarkColor = color
    }
}
