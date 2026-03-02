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
        let all = (try? modelContext.fetch(FetchDescriptor<ReadingPosition>())) ?? []
        return all.first { $0.surahId == surahId }
    }
}
