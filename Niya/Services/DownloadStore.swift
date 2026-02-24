import Foundation
import SwiftData

@Observable
@MainActor
final class DownloadStore {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func isDownloaded(surahId: Int) -> Bool {
        let descriptor = FetchDescriptor<AudioDownload>(
            predicate: #Predicate { $0.surahId == surahId }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    func save(surahId: Int, filename: String) throws {
        let download = AudioDownload(surahId: surahId, localFileName: filename)
        modelContext.insert(download)
        try modelContext.save()
    }

    func delete(surahId: Int) throws {
        let descriptor = FetchDescriptor<AudioDownload>(
            predicate: #Predicate { $0.surahId == surahId }
        )
        let results = try modelContext.fetch(descriptor)
        for item in results {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func allDownloads() throws -> [AudioDownload] {
        try modelContext.fetch(FetchDescriptor<AudioDownload>())
    }
}
