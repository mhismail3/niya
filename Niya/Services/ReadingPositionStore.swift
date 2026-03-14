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
        let all = fetchAll().sorted { $0.lastReadAt > $1.lastReadAt }
        var seen = Set<Int>()
        var result: [ReadingPosition] = []
        var toDelete: [ReadingPosition] = []
        for item in all {
            if seen.insert(item.surahId).inserted {
                result.append(item)
            } else {
                toDelete.append(item)
            }
        }
        if !toDelete.isEmpty {
            for dupe in toDelete { modelContext.delete(dupe) }
            do { try modelContext.save() } catch { AppLogger.store.error("ReadingPositionStore dedup save: \(error)") }
        }
        return result
    }

    func clearAll() {
        for item in fetchAll() {
            modelContext.delete(item)
        }
        do { try modelContext.save() } catch { AppLogger.store.error("ReadingPositionStore clearAll failed: \(error)") }
    }

    func position(for surahId: Int) -> ReadingPosition? {
        let targetSurah = surahId
        var descriptor = FetchDescriptor<ReadingPosition>(
            predicate: #Predicate { $0.surahId == targetSurah }
        )
        descriptor.fetchLimit = 2
        let matches = (try? modelContext.fetch(descriptor)) ?? []
        guard let keeper = matches.max(by: { $0.lastReadAt < $1.lastReadAt }) else { return nil }
        if matches.count > 1 {
            for dupe in matches where dupe !== keeper {
                modelContext.delete(dupe)
            }
            do { try modelContext.save() } catch { AppLogger.store.error("ReadingPositionStore dedup save: \(error)") }
        }
        return keeper
    }

    private func fetchAll() -> [ReadingPosition] {
        (try? modelContext.fetch(FetchDescriptor<ReadingPosition>())) ?? []
    }
}
