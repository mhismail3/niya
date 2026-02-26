import Foundation

struct Dua: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let arabic: String
    let translation: String
    let transliteration: String?
    let `repeat`: Int?
    let source: String?
    let benefits: String?
}
