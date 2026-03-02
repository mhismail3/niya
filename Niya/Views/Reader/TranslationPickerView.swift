import SwiftUI

struct TranslationPickerView: View {
    @Environment(QuranDataService.self) private var dataService

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
                                    try? await dataService.addTranslation(edition)
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(edition.name)
                                        .font(.niyaBody)
                                        .foregroundStyle(Color.niyaText)
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
    }
}
