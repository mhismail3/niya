import Foundation
import SwiftData

@Model
final class RecentDua {
    @Attribute(.unique) var duaKey: String
    var categoryId: Int
    var duaId: Int
    var visitedAt: Date

    init(categoryId: Int, duaId: Int, visitedAt: Date = .now) {
        self.duaKey = "\(categoryId):\(duaId)"
        self.categoryId = categoryId
        self.duaId = duaId
        self.visitedAt = visitedAt
    }
}
