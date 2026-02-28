import SwiftUI

struct TranslationPickerView: View {
    @Environment(QuranDataService.self) private var dataService
    @AppStorage("selectedTranslation") private var selectedId: String = "en_sahih"

    private var grouped: [(language: String, editions: [TranslationEdition])] {
        let byLang = Dictionary(grouping: dataService.availableTranslations, by: \.languageName)
        return byLang.keys.sorted().map { (language: $0, editions: byLang[$0]!) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.language) { group in
                Section(group.language) {
                    ForEach(group.editions) { edition in
                        Button {
                            Task { try? await dataService.loadTranslation(edition) }
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
                                if edition.id == selectedId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.niyaTeal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Translation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
