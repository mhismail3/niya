import Foundation
import SwiftData

@Model
final class HadithBookmark {
    var hadithKey: String = ""
    var collectionId: String = ""
    var hadithId: Int = 0
    var colorTag: String?
    var createdAt: Date = Date.distantPast

    var bookmarkColor: BookmarkColor? {
        get { colorTag.flatMap(BookmarkColor.init(rawValue:)) }
        set { colorTag = newValue?.rawValue }
    }

    init(collectionId: String, hadithId: Int, createdAt: Date = .now) {
        self.hadithKey = "\(collectionId):\(hadithId)"
        self.collectionId = collectionId
        self.hadithId = hadithId
        self.createdAt = createdAt
    }
}
