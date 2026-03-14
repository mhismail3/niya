import Foundation
import SwiftData

@MainActor
final class DownloadStore {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isDownloaded(surahId: Int, reciterId: String = "alAfasy") -> Bool {
        let targetSurah = surahId
        let targetReciter = reciterId
        var descriptor = FetchDescriptor<AudioDownload>(
            predicate: #Predicate { $0.surahId == targetSurah && $0.reciterId == targetReciter }
        )
        descriptor.fetchLimit = 1
        return ((try? modelContext.fetch(descriptor)) ?? []).first != nil
    }

    func save(surahId: Int, filename: String, reciterId: String = "alAfasy") throws {
        let download = AudioDownload(surahId: surahId, localFileName: filename, reciterId: reciterId)
        modelContext.insert(download)
        try modelContext.save()
    }

    func delete(surahId: Int, reciterId: String = "alAfasy") throws {
        let targetSurah = surahId
        let targetReciter = reciterId
        let descriptor = FetchDescriptor<AudioDownload>(
            predicate: #Predicate { $0.surahId == targetSurah && $0.reciterId == targetReciter }
        )
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func allDownloads() throws -> [AudioDownload] {
        try modelContext.fetch(FetchDescriptor<AudioDownload>())
    }
}
