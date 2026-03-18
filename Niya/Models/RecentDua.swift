import Foundation
import SwiftData

@Model
final class RecentDua {
    var duaKey: String = ""
    var categoryId: Int = 0
    var duaId: Int = 0
    var visitedAt: Date = Date.distantPast

    var categorySlug: String { duaKey.components(separatedBy: ":").first ?? "" }
    var duaStringId: String {
        let parts = duaKey.components(separatedBy: ":")
        return parts.count > 1 ? parts.dropFirst().joined(separator: ":") : ""
    }

    init(categoryId: String, duaId: String, visitedAt: Date = .now) {
        self.duaKey = "\(categoryId):\(duaId)"
        self.categoryId = 0
        self.duaId = 0
        self.visitedAt = visitedAt
    }
}
