import Foundation

struct Verse: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let text: String
    let translation: String
    let transliteration: String?
    let page: Int
}
