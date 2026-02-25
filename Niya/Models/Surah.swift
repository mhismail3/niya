import Foundation

struct Surah: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let transliteration: String
    let translation: String
    let type: String
    let totalVerses: Int
    let startPage: Int

    var isMakkan: Bool { type.lowercased() == "meccan" }
}
