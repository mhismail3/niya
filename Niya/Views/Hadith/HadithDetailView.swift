import SwiftUI

struct HadithDetailView: View {
    let hadith: Hadith
    let collectionId: String
    let hasGrades: Bool
    @Environment(HadithDataService.self) private var dataService
    @Environment(\.stores) private var stores
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @AppStorage(StorageKey.hadithArabicFontSize) private var hadithArabicFontSize: Double = 22
    @AppStorage(StorageKey.translationFontSize) private var translationFontSize: Double = 16
    @State private var isBookmarked = false

    private var collectionName: String {
        dataService.collections.first { $0.id == collectionId }?.name ?? collectionId
    }

    private var shareText: String {
        var parts: [String] = []
        if !hadith.narrator.isEmpty { parts.append(hadith.narrator) }
        if !hadith.text.isEmpty {
            parts.append(hadith.text)
        } else {
            parts.append(hadith.arabic)
        }
        parts.append("\(collectionName), Hadith #\(hadith.id)")
        if let grade = hadith.grade { parts.append("Grade: \(grade)") }
        return parts.joined(separator: "\n\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gradeBadge

                Text(hadith.arabic)
                    .font(.quranText(script: script, size: hadithArabicFontSize))
                    .foregroundStyle(Color.niyaText)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if !hadith.text.isEmpty || !hadith.narrator.isEmpty {
                    Divider()

                    if !hadith.narrator.isEmpty {
                        Text(hadith.narrator)
                            .font(.system(.subheadline, design: .serif))
                            .italic()
                            .foregroundStyle(Color.niyaGold)
                    }

                    Text(hadith.text)
                        .font(.system(size: translationFontSize, design: .serif))
                        .foregroundStyle(Color.niyaText)
                        .lineSpacing(4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    metadataRow("Book", value: collectionName)
                    metadataRow("Hadith", value: "#\(hadith.id)")
                }

                actionBar
            }
            .padding()
        }
        .background(Color.niyaBackground)
        .navigationBarTitleDisplayMode(.inline)
        .niyaToolbar()
        .onAppear {
            isBookmarked = stores.hadithBookmarks.isBookmarked(collectionId: collectionId, hadithId: hadith.id)
            stores.recentHadith
                .record(collectionId: collectionId, hadithId: hadith.id, hasGrades: hasGrades)
        }
    }

    @ViewBuilder
    private var gradeBadge: some View {
        if hasGrades, let grade = HadithGrade.from(hadith.grade) {
            Text(grade.displayName)
                .font(.system(.caption, design: .serif, weight: .semibold))
                .foregroundStyle(grade.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(grade.color.opacity(0.12))
                .clipShape(Capsule())
        } else if hasGrades, let gradeText = hadith.grade {
            Text(gradeText)
                .font(.system(.caption, design: .serif, weight: .semibold))
                .foregroundStyle(Color.niyaSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.niyaSecondary.opacity(0.12))
                .clipShape(Capsule())
        } else if !hasGrades {
            Text("Grade not available")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
            Text(value)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 24) {
            Button {
                stores.hadithBookmarks.toggle(collectionId: collectionId, hadithId: hadith.id)
                isBookmarked.toggle()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.niyaVerseAction)
                    .foregroundStyle(isBookmarked ? Color.niyaGold : Color.niyaSecondary)
            }
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.niyaVerseAction)
                    .foregroundStyle(Color.niyaSecondary)
            }
            .accessibilityLabel("Share hadith")

            Button {
                UIPasteboard.general.string = shareText
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.niyaVerseAction)
                    .foregroundStyle(Color.niyaSecondary)
            }
            .accessibilityLabel("Copy hadith text")

            Spacer()
        }
        .padding(.top, 8)
    }
}
