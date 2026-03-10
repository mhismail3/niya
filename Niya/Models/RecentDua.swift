import Foundation
import SwiftData

@Model
final class RecentDua {
    var duaKey: String = ""
    var categoryId: Int = 0
    var duaId: Int = 0
    var visitedAt: Date = Date.distantPast

    init(categoryId: Int, duaId: Int, visitedAt: Date = .now) {
        self.duaKey = "\(categoryId):\(duaId)"
        self.categoryId = categoryId
        self.duaId = duaId
        self.visitedAt = visitedAt
    }
}
