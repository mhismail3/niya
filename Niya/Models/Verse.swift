import Foundation

struct TranslationText: Hashable, Sendable {
    let name: String
    let text: String
    let isRTL: Bool
}

struct Verse: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
    let translation: String
    let transliteration: String?
    let page: Int
    var extraTranslations: [TranslationText] = []

    enum CodingKeys: String, CodingKey {
        case id, text, translation, transliteration, page
    }
}
