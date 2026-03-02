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
        .onAppear {
            tafsirService.fetch(edition: selectedEdition, surahId: surahId, ayahId: ayahId)
        }
        .onChange(of: selectedEdition) { _, newEdition in
            tafsirService.fetch(edition: newEdition, surahId: surahId, ayahId: ayahId)
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
        if tafsirService.isLoading(edition: selectedEdition, surahId: surahId, ayahId: ayahId) {
            Spacer()
            ProgressView()
            Spacer()
        } else if let entry = tafsirService.entry(edition: selectedEdition, surahId: surahId, ayahId: ayahId) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedEdition.author)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)

                    Text(selectedEdition.subtitle)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary.opacity(0.7))

                    if entry.text.isEmpty {
                        Text("No commentary available for this verse.")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.niyaSecondary)
                            .italic()
                    } else {
                        ForEach(Array(entry.text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, paragraph in
                            if !paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
                                let isArabicBlock = paragraph.unicodeScalars.filter(\.properties.isAlphabetic).allSatisfy(isArabicScalar)
                                if isArabicBlock {
                                    Text(paragraph)
                                        .font(.custom("NotoNaskhArabic", size: 20))
                                        .foregroundStyle(Color.niyaText)
                                        .multilineTextAlignment(.trailing)
                                        .lineSpacing(12)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .textSelection(.enabled)
                                } else {
                                    Text(styledTafsirText(paragraph))
                                        .font(.system(.body, design: .serif))
                                        .foregroundStyle(Color.niyaText)
                                        .textSelection(.enabled)
                                        .lineSpacing(4)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        } else if tafsirService.hasFailed(edition: selectedEdition, surahId: surahId, ayahId: ayahId) {
            ContentUnavailableView {
                Label("Unable to Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Could not load tafsir. Check your connection and try again.")
            } actions: {
                Button("Retry") {
                    tafsirService.fetch(edition: selectedEdition, surahId: surahId, ayahId: ayahId)
                }
            }
        } else {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private func isArabicScalar(_ s: Unicode.Scalar) -> Bool {
        (0x0600...0x06FF).contains(s.value) ||  // Arabic
        (0x0750...0x077F).contains(s.value) ||  // Arabic Supplement
        (0x08A0...0x08FF).contains(s.value) ||  // Arabic Extended-A
        (0xFB50...0xFDFF).contains(s.value) ||  // Arabic Presentation Forms-A
        (0xFE70...0xFEFF).contains(s.value)     // Arabic Presentation Forms-B
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
            let charIsArabic = scalars.contains { isArabicScalar($0) && $0.properties.isAlphabetic }
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
