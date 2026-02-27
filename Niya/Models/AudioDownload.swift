import Foundation
import SwiftData

@Model
final class AudioDownload {
    var surahId: Int
    var localFileName: String
    var downloadedAt: Date
    var reciterId: String

    init(surahId: Int, localFileName: String, downloadedAt: Date = .now, reciterId: String = "alAfasy") {
        self.surahId = surahId
        self.localFileName = localFileName
        self.downloadedAt = downloadedAt
        self.reciterId = reciterId
    }
}
