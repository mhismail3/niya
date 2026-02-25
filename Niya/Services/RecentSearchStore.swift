import Foundation
import SwiftData

@MainActor
final class RecentSearchStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Remove existing duplicate
        let all = fetchAll()
        for existing in all where existing.query.lowercased() == trimmed.lowercased() && existing.surahId == nil {
            modelContext.delete(existing)
        }
        modelContext.insert(RecentSearch(query: trimmed))
        try? modelContext.save()
    }

    func saveSurah(_ surahId: Int, name: String) {
        let all = fetchAll()
        for existing in all where existing.surahId == surahId {
            modelContext.delete(existing)
        }
        modelContext.insert(RecentSearch(query: name, surahId: surahId))
        try? modelContext.save()
    }

    func recentQueries() -> [RecentSearch] {
        fetchAll()
            .filter { $0.surahId == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func recentSurahs() -> [RecentSearch] {
        fetchAll()
            .filter { $0.surahId != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func delete(_ item: RecentSearch) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    func clearAll() {
        for item in fetchAll() {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func fetchAll() -> [RecentSearch] {
        (try? modelContext.fetch(FetchDescriptor<RecentSearch>())) ?? []
    }
}
