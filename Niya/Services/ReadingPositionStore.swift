import Foundation
import SwiftData

@MainActor
final class ReadingPositionStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(surahId: Int, ayahId: Int) {
        if let existing = position(for: surahId) {
            existing.lastAyahId = ayahId
            existing.lastReadAt = .now
        } else {
            modelContext.insert(ReadingPosition(surahId: surahId, lastAyahId: ayahId))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("ReadingPositionStore save failed: \(error)") }
    }

    func recentPositions() -> [ReadingPosition] {
        let descriptor = FetchDescriptor<ReadingPosition>(
            sortBy: [SortDescriptor(\.lastReadAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func position(for surahId: Int) -> ReadingPosition? {
        var descriptor = FetchDescriptor<ReadingPosition>(
            predicate: #Predicate<ReadingPosition> { $0.surahId == surahId }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }
}
