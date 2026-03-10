import Foundation
import SwiftData

@MainActor
final class RecentDuaStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(categoryId: Int, duaId: Int) {
        let key = "\(categoryId):\(duaId)"
        let all = (try? modelContext.fetch(FetchDescriptor<RecentDua>())) ?? []
        let matches = all.filter { $0.duaKey == key }
        if let existing = matches.max(by: { $0.visitedAt < $1.visitedAt }) {
            existing.visitedAt = .now
            for dupe in matches where dupe !== existing {
                modelContext.delete(dupe)
            }
        } else {
            modelContext.insert(RecentDua(categoryId: categoryId, duaId: duaId))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentDuaStore save failed: \(error)") }
    }

    func clearAll() {
        let all = (try? modelContext.fetch(FetchDescriptor<RecentDua>())) ?? []
        for item in all {
            modelContext.delete(item)
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentDuaStore clearAll failed: \(error)") }
    }

    func recentDuas(limit: Int = 20) -> [RecentDua] {
        let descriptor = FetchDescriptor<RecentDua>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        var seen = Set<String>()
        var result: [RecentDua] = []
        var toDelete: [RecentDua] = []
        for item in all {
            if seen.insert(item.duaKey).inserted {
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
