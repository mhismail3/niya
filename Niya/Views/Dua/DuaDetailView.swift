import SwiftUI

struct DuaDetailView: View {
    let dua: Dua
    let categoryId: Int
    @Environment(DuaDataService.self) private var dataService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hadithArabicFontSize") private var arabicFontSize: Double = 22
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @State private var isBookmarked = false

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
            let store = DuaBookmarkStore(modelContext: modelContext)
            isBookmarked = store.isBookmarked(categoryId: categoryId, duaId: dua.id)
            RecentDuaStore(modelContext: modelContext)
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
                let store = DuaBookmarkStore(modelContext: modelContext)
                store.toggle(categoryId: categoryId, duaId: dua.id)
                isBookmarked.toggle()
            } label: {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(isBookmarked ? .red : Color.niyaSecondary)
            }

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(Color.niyaSecondary)
            }

            Button {
                UIPasteboard.general.string = shareText
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.title3)
                    .foregroundStyle(Color.niyaSecondary)
            }

            Spacer()
        }
        .padding(.top, 8)
    }
}
