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
        if let existing = all.first(where: { $0.duaKey == key }) {
            existing.visitedAt = .now
        } else {
            modelContext.insert(RecentDua(categoryId: categoryId, duaId: duaId))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentDuaStore save failed: \(error)") }
    }

    func recentDuas(limit: Int = 20) -> [RecentDua] {
        var descriptor = FetchDescriptor<RecentDua>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
