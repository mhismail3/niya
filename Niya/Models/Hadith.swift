import Foundation

struct Hadith: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let chapterId: Int
    let arabic: String
    let narrator: String
    let text: String
    let grade: String?
    let gradeArabic: String?
}
