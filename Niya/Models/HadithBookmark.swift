import Foundation
import SwiftData

@Model
final class HadithBookmark {
    @Attribute(.unique) var hadithKey: String
    var collectionId: String
    var hadithId: Int
    var colorTag: String?
    var createdAt: Date

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
