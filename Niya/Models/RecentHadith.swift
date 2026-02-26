import Foundation
import SwiftData

@Model
final class RecentHadith {
    @Attribute(.unique) var hadithKey: String
    var collectionId: String
    var hadithId: Int
    var hasGrades: Bool
    var visitedAt: Date

    init(collectionId: String, hadithId: Int, hasGrades: Bool, visitedAt: Date = .now) {
        self.hadithKey = "\(collectionId):\(hadithId)"
        self.collectionId = collectionId
        self.hadithId = hadithId
        self.hasGrades = hasGrades
        self.visitedAt = visitedAt
    }
}
