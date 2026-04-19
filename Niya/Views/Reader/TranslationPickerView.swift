import SwiftUI

struct TranslationPickerView: View {
    @Environment(QuranDataService.self) private var dataService
    @State private var errorMessage: String?

    private var grouped: [(language: String, editions: [TranslationEdition])] {
        let byLang = Dictionary(grouping: dataService.availableTranslations, by: \.languageName)
        return byLang.keys.sorted().map { (language: $0, editions: byLang[$0]!) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.language) { group in
                Section(group.language) {
                    ForEach(group.editions) { edition in
                        let isSelected = dataService.isTranslationSelected(edition)
                        Button {
                            Task {
                                if isSelected {
                                    dataService.removeTranslation(edition)
                                } else {
                                    do {
                                        try await dataService.addTranslation(edition)
                                    } catch {
                                        errorMessage = "Couldn't load \(edition.name): \(error.localizedDescription)"
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 6) {
                                        Text(edition.name)
                                            .font(.niyaBody)
                                            .foregroundStyle(Color.niyaText)
                                        if edition.hasWordByWord {
                                            Text("Word-by-Word")
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.niyaTeal.opacity(0.8), in: Capsule())
                                        }
                                    }
                                    Text(edition.author)
                                        .font(.niyaCaption)
                                        .foregroundStyle(Color.niyaSecondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.niyaTeal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Translations")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Translation Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
