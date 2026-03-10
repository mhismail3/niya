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
        let all = fetchAll()
        for existing in all where existing.query.lowercased() == trimmed.lowercased() && existing.surahId == nil {
            modelContext.delete(existing)
        }
        modelContext.insert(RecentSearch(query: trimmed))
        do { try modelContext.save() } catch { AppLogger.store.error("RecentSearchStore save failed: \(error)") }
    }

    func saveSurah(_ surahId: Int, name: String) {
        let all = fetchAll()
        for existing in all where existing.surahId == surahId {
            modelContext.delete(existing)
        }
        modelContext.insert(RecentSearch(query: name, surahId: surahId))
        do { try modelContext.save() } catch { AppLogger.store.error("RecentSearchStore save failed: \(error)") }
    }

    func recentQueries() -> [RecentSearch] {
        var seen = Set<String>()
        var result: [RecentSearch] = []
        var toDelete: [RecentSearch] = []
        let all = fetchAll().filter { $0.surahId == nil }.sorted { $0.createdAt > $1.createdAt }
        for item in all {
            let normalized = item.query.lowercased()
            if seen.insert(normalized).inserted {
                result.append(item)
            } else {
                toDelete.append(item)
            }
        }
        if !toDelete.isEmpty {
            for dupe in toDelete { modelContext.delete(dupe) }
            try? modelContext.save()
        }
        return result
    }

    func recentSurahs() -> [RecentSearch] {
        var seen = Set<Int>()
        var result: [RecentSearch] = []
        var toDelete: [RecentSearch] = []
        let all = fetchAll().filter { $0.surahId != nil }.sorted { $0.createdAt > $1.createdAt }
        for item in all {
            if let sid = item.surahId, seen.insert(sid).inserted {
                result.append(item)
            } else if item.surahId != nil {
                toDelete.append(item)
            }
        }
        if !toDelete.isEmpty {
            for dupe in toDelete { modelContext.delete(dupe) }
            try? modelContext.save()
        }
        return result
    }

    func delete(_ item: RecentSearch) {
        modelContext.delete(item)
        do { try modelContext.save() } catch { AppLogger.store.error("RecentSearchStore save failed: \(error)") }
    }

    func clearAll() {
        for item in fetchAll() {
            modelContext.delete(item)
        }
        do { try modelContext.save() } catch { AppLogger.store.error("RecentSearchStore save failed: \(error)") }
    }

    private func fetchAll() -> [RecentSearch] {
        (try? modelContext.fetch(FetchDescriptor<RecentSearch>())) ?? []
    }
}
