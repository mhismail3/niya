import Foundation
import SwiftData

@Model
final class DuaBookmark {
    @Attribute(.unique) var duaKey: String
    var categoryId: Int
    var duaId: Int
    var colorTag: String?
    var createdAt: Date

    var bookmarkColor: BookmarkColor? {
        get { colorTag.flatMap(BookmarkColor.init(rawValue:)) }
        set { colorTag = newValue?.rawValue }
    }

    init(categoryId: Int, duaId: Int, createdAt: Date = .now) {
        self.duaKey = "\(categoryId):\(duaId)"
        self.categoryId = categoryId
        self.duaId = duaId
        self.createdAt = createdAt
    }
}
