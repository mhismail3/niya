import Foundation
import SwiftData

@Model
final class AudioDownload {
    @Attribute(.unique) var surahId: Int
    var localFileName: String
    var downloadedAt: Date

    init(surahId: Int, localFileName: String, downloadedAt: Date = .now) {
        self.surahId = surahId
        self.localFileName = localFileName
        self.downloadedAt = downloadedAt
    }
}
