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
        if let existing = all.first(where: { $0.hadithKey == key }) {
            existing.visitedAt = .now
        } else {
            modelContext.insert(RecentHadith(collectionId: collectionId, hadithId: hadithId, hasGrades: hasGrades))
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentHadithStore save failed: \(error)") }
    }

    func recentHadiths(limit: Int = 20) -> [RecentHadith] {
        var descriptor = FetchDescriptor<RecentHadith>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
