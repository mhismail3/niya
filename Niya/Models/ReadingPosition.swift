import Foundation
import SwiftData

@Model
final class ReadingPosition {
    var surahId: Int = 0
    var lastAyahId: Int = 0
    var lastReadAt: Date = Date.distantPast

    init(surahId: Int, lastAyahId: Int, lastReadAt: Date = .now) {
        self.surahId = surahId
        self.lastAyahId = lastAyahId
        self.lastReadAt = lastReadAt
    }
}
