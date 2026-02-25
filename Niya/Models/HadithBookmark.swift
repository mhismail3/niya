import Foundation
import SwiftData

@Model
final class HadithBookmark {
    @Attribute(.unique) var hadithKey: String
    var collectionId: String
    var hadithId: Int
    var createdAt: Date

    init(collectionId: String, hadithId: Int, createdAt: Date = .now) {
        self.hadithKey = "\(collectionId):\(hadithId)"
        self.collectionId = collectionId
        self.hadithId = hadithId
        self.createdAt = createdAt
    }
}
