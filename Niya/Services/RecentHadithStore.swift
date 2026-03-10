import Foundation
import SwiftData

@MainActor
final class RecentHadithStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(collectionId: String, hadithId: Int, hasGrades: Bool) {
        let key = "\(collectionId):\(hadithId)"
        let all = (try? modelContext.fetch(FetchDescriptor<RecentHadith>())) ?? []
        let matches = all.filter { $0.hadithKey == key }
        if let existing = matches.max(by: { $0.visitedAt < $1.visitedAt }) {
            existing.visitedAt = .now
            for dupe in matches where dupe !== existing {
                modelContext.delete(dupe)
            }
        } else {
            modelContext.insert(RecentHadith(collectionId: collectionId, hadithId: hadithId, hasGrades: hasGrades))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentHadithStore save failed: \(error)") }
    }

    func clearAll() {
        let all = (try? modelContext.fetch(FetchDescriptor<RecentHadith>())) ?? []
        for item in all {
            modelContext.delete(item)
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentHadithStore clearAll failed: \(error)") }
    }

    func recentHadiths(limit: Int = 20) -> [RecentHadith] {
        let descriptor = FetchDescriptor<RecentHadith>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        var seen = Set<String>()
        var result: [RecentHadith] = []
        var toDelete: [RecentHadith] = []
        for item in all {
            if seen.insert(item.hadithKey).inserted {
                result.append(item)
            } else {
                toDelete.append(item)
            }
        }
        if !toDelete.isEmpty {
            for dupe in toDelete { modelContext.delete(dupe) }
            try? modelContext.save()
        }
        return Array(result.prefix(limit))
    }
}
