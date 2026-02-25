import Foundation

struct HadithCollection: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let nameArabic: String
    let author: String
    let totalHadiths: Int
    let totalChapters: Int
    let hasGrades: Bool
}
