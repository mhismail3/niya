import Foundation
import SwiftData

@Model
final class DuaBookmark {
    var duaKey: String = ""
    var categoryId: Int = 0
    var duaId: Int = 0
    var colorTag: String?
    var createdAt: Date = Date.distantPast

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
