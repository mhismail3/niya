import Foundation
import SwiftData

@Model
final class RecentSearch {
    var query: String = ""
    var surahId: Int?
    var createdAt: Date = Date.distantPast

    init(query: String, surahId: Int? = nil, createdAt: Date = .now) {
        self.query = query
        self.surahId = surahId
        self.createdAt = createdAt
    }
}
