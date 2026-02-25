import Foundation
import SwiftData

@Model
final class ReadingPosition {
    @Attribute(.unique) var surahId: Int
    var lastAyahId: Int
    var lastReadAt: Date

    init(surahId: Int, lastAyahId: Int, lastReadAt: Date = .now) {
        self.surahId = surahId
        self.lastAyahId = lastAyahId
        self.lastReadAt = lastReadAt
    }
}
