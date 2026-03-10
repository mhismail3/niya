import Foundation
import SwiftData

@Model
final class QuranBookmark {
    var verseKey: String = ""
    var surahId: Int = 0
    var ayahId: Int = 0
    var colorTag: String?
    var createdAt: Date = Date.distantPast

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
