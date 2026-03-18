import Foundation
import SwiftData

@Model
final class DuaBookmark {
    var duaKey: String = ""
    var categoryId: Int = 0
    var duaId: Int = 0
    var colorTag: String?
    var createdAt: Date = Date.distantPast

    var categorySlug: String { duaKey.components(separatedBy: ":").first ?? "" }
    var duaStringId: String {
        let parts = duaKey.components(separatedBy: ":")
        return parts.count > 1 ? parts.dropFirst().joined(separator: ":") : ""
    }

    var bookmarkColor: BookmarkColor? {
        get { colorTag.flatMap(BookmarkColor.init(rawValue:)) }
        set { colorTag = newValue?.rawValue }
    }

    init(categoryId: String, duaId: String, createdAt: Date = .now) {
        self.duaKey = "\(categoryId):\(duaId)"
        self.categoryId = 0
        self.duaId = 0
        self.createdAt = createdAt
    }
}
