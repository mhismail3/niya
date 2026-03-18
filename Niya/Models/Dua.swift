import Foundation

struct Dua: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let arabic: String
    let translation: String?
    let transliteration: String?
    let `repeat`: Int?
    let reference: String?
    let benefits: String?
    let context: String?
    let arabicOnly: Bool?
}
