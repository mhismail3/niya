import Foundation
import SwiftData

@Model
final class QuranBookmark {
    @Attribute(.unique) var verseKey: String
    var surahId: Int
    var ayahId: Int
    var createdAt: Date

    init(surahId: Int, ayahId: Int, createdAt: Date = .now) {
        self.verseKey = "\(surahId):\(ayahId)"
        self.surahId = surahId
        self.ayahId = ayahId
        self.createdAt = createdAt
    }
}
