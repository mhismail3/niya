import Foundation
import SwiftData

@MainActor
final class DownloadStore {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isDownloaded(surahId: Int, reciterId: String = "alAfasy") -> Bool {
        let all = (try? modelContext.fetch(FetchDescriptor<AudioDownload>())) ?? []
        return all.contains { $0.surahId == surahId && $0.reciterId == reciterId }
    }

    func save(surahId: Int, filename: String, reciterId: String = "alAfasy") throws {
        let download = AudioDownload(surahId: surahId, localFileName: filename, reciterId: reciterId)
        modelContext.insert(download)
        try modelContext.save()
    }

    func delete(surahId: Int, reciterId: String = "alAfasy") throws {
        let all = try modelContext.fetch(FetchDescriptor<AudioDownload>())
        for item in all where item.surahId == surahId && item.reciterId == reciterId {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func allDownloads() throws -> [AudioDownload] {
        try modelContext.fetch(FetchDescriptor<AudioDownload>())
    }
}
