import Foundation
import SwiftData

@Model
final class RecentHadith {
    var hadithKey: String = ""
    var collectionId: String = ""
    var hadithId: Int = 0
    var hasGrades: Bool = false
    var visitedAt: Date = Date.distantPast

    init(collectionId: String, hadithId: Int, hasGrades: Bool, visitedAt: Date = .now) {
        self.hadithKey = "\(collectionId):\(hadithId)"
        self.collectionId = collectionId
        self.hadithId = hadithId
        self.hasGrades = hasGrades
        self.visitedAt = visitedAt
    }
}
