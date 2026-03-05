import Foundation
import SwiftData

@Model
final class QuranBookmark {
    @Attribute(.unique) var verseKey: String
    var surahId: Int
    var ayahId: Int
    var colorTag: String?
    var createdAt: Date

    var bookmarkColor: BookmarkColor? {
        get { colorTag.flatMap(BookmarkColor.init(rawValue:)) }
        set { colorTag = newValue?.rawValue }
    }

    init(surahId: Int, ayahId: Int, createdAt: Date = .now) {
        self.verseKey = "\(surahId):\(ayahId)"
        self.surahId = surahId
        self.ayahId = ayahId
        self.createdAt = createdAt
    }
}
