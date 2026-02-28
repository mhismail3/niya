import Foundation

struct TranslationEdition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let language: String
    let languageName: String
    let name: String
    let author: String
    let filename: String

    var isRTL: Bool {
        ["ur", "fa", "ar"].contains(language)
    }
}
