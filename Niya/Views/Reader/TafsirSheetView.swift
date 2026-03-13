import SwiftUI

struct TafsirSheetView: View {
    let surahId: Int
    let ayahId: Int
    let surahName: String
    @Environment(TafsirService.self) private var tafsirService
    @AppStorage(StorageKey.selectedTafsir) private var selectedEdition: TafsirEdition = .ibnKathir
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editionPicker
                    .padding(.vertical, 8)

                Divider()

                contentArea
            }
            .navigationTitle("Surah \(surahName), Verse \(ayahId)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var editionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TafsirEdition.allCases) { edition in
                    Button {
                        selectedEdition = edition
                    } label: {
                        Text(edition.displayName)
                            .font(.niyaSubheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedEdition == edition
                                    ? Color.niyaTeal.opacity(0.15)
                                    : Color.niyaSurface
                            )
                            .foregroundStyle(
                                selectedEdition == edition
                                    ? Color.niyaTeal
                                    : Color.niyaSecondary
                            )
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        let tafsirText = tafsirService.text(edition: selectedEdition, surahId: surahId, ayahId: ayahId)
        if let tafsirText, !tafsirText.isEmpty {
            let blocks = TafsirBlockParser.parse(tafsirText)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedEdition.author)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)

                    Text(selectedEdition.subtitle)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary.opacity(0.7))

                    ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                        blockView(block, previousBlock: index > 0 ? blocks[index - 1] : nil)
                    }
                }
                .padding()
            }
        } else {
            ContentUnavailableView {
                Label("No Commentary", systemImage: "text.book.closed")
            } description: {
                Text("No commentary available for this verse.")
            }
        }
    }

    private func topSpacing(for block: TafsirBlock, after previous: TafsirBlock?) -> CGFloat {
        guard let previous else { return 0 }
        switch (previous, block) {
        case (.commentary, .quoteGroup): return 8
        case (.commentary, .arabicQuote): return 8
        case (.quoteGroup, .commentary): return 8
        case (.translation, .commentary): return 8
        case (.arabicQuote, .commentary): return 8
        case (.quoteGroup, .quoteGroup): return 8
        case (.quoteGroup, .arabicQuote): return 8
        default: return 0
        }
    }

    @ViewBuilder
    private func blockView(_ block: TafsirBlock, previousBlock: TafsirBlock?) -> some View {
        let extra = topSpacing(for: block, after: previousBlock)
        Group {
            switch block {
            case .heading(let text):
                Text(text)
                    .font(.niyaHeadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.niyaText)
                    .padding(.top, 20)

            case .arabicQuote(let text):
                Text(text)
                    .font(.custom("NotoNaskhArabic", size: 20))
                    .foregroundStyle(Color.niyaText)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.niyaGold.opacity(0.4))
                            .frame(width: 3)
                    }
                    .textSelection(.enabled)

            case .translation(let text):
                Text(highlightVerseRefs(text))
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(Color.niyaSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)

            case .quoteGroup(let arabic, let translation):
                VStack(alignment: .leading, spacing: 6) {
                    Text(arabic)
                        .font(.custom("NotoNaskhArabic", size: 20))
                        .foregroundStyle(Color.niyaText)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(12)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .textSelection(.enabled)

                    Text(highlightVerseRefs(translation))
                        .font(.system(.subheadline, design: .serif))
                        .italic()
                        .foregroundStyle(Color.niyaSecondary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.niyaGold.opacity(0.4))
                        .frame(width: 3)
                }

            case .commentary(let text):
                Text(styledTafsirText(text))
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.niyaText)
                    .textSelection(.enabled)
                    .lineSpacing(4)
            }
        }
        .padding(.top, extra)
    }

    private func highlightVerseRefs(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let pattern = /\(\d+:\d+(?:-\d+)?\)/
        for match in text.matches(of: pattern) {
            guard let range = result.range(of: String(match.output), locale: nil) else { continue }
            result[range].foregroundColor = Color.niyaTeal.opacity(0.8)
        }
        return result
    }

    private func styledTafsirText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var current = ""
        var currentIsArabic = false

        func flush() {
            guard !current.isEmpty else { return }
            var segment = AttributedString(current)
            if currentIsArabic {
                segment.font = .custom("NotoNaskhArabic", size: 20)
            }
            result.append(segment)
            current = ""
        }

        for char in text {
            let scalars = char.unicodeScalars
            let charIsArabic = scalars.contains { TafsirBlockParser.isArabicScalar($0) && $0.properties.isAlphabetic }
            if charIsArabic != currentIsArabic && !current.isEmpty {
                flush()
            }
            currentIsArabic = charIsArabic
            current.append(char)
        }
        flush()
        return result
    }
}
