import Foundation
import SwiftUI

enum ReaderMode: String, CaseIterable {
    case scroll = "Scroll"
    case page = "Page"
}

@Observable
@MainActor
final class ReaderViewModel {
    var mode: ReaderMode = .scroll
    var script: QuranScript
    var currentPage: Int = 0
    var initialAyahId: Int?
    var visibleAyahId: Int = 1
    var isSettled = false
    var hasUserScrolled = false
    var goToAyahTarget: Int?
    var highlightedAyahId: Int?

    let surah: Surah
    private let dataService: QuranDataService

    var verses: [Verse] = []
    var pages: [[Verse]] = []

    init(surah: Surah, dataService: QuranDataService, script: QuranScript, initialAyahId: Int? = nil) {
        self.surah = surah
        self.dataService = dataService
        self.script = script
        self.initialAyahId = initialAyahId
    }

    func load() {
        verses = dataService.verses(for: surah.id, script: script)
        pages = dataService.pages(for: surah.id, script: script)

        if let target = initialAyahId {
            visibleAyahId = target
            if let pageIndex = pages.firstIndex(where: { page in
                page.contains { $0.id == target }
            }) {
                currentPage = pageIndex
            } else {
                currentPage = 0
            }
        } else {
            currentPage = 0
            visibleAyahId = verses.first?.id ?? 1
        }
    }

    func updateVisibleAyah(_ ayahId: Int) {
        guard isSettled else { return }
        hasUserScrolled = true
        visibleAyahId = ayahId
    }

    func goToAyah(_ ayahId: Int) {
        let clamped = max(1, min(ayahId, surah.totalVerses))

        if let pageIndex = pages.firstIndex(where: { $0.contains { $0.id == clamped } }) {
            currentPage = pageIndex
        }

        visibleAyahId = clamped
        hasUserScrolled = true
        goToAyahTarget = clamped
        highlightedAyahId = clamped
    }

    func clearHighlight() {
        highlightedAyahId = nil
    }

    func reloadForScript(_ newScript: QuranScript) {
        script = newScript
        load()
    }

    func reloadTranslation() {
        verses = dataService.verses(for: surah.id, script: script)
        pages = dataService.pages(for: surah.id, script: script)
    }

    var showBismillah: Bool {
        surah.id != 9
    }

    var pageLabel: String {
        guard !pages.isEmpty else { return "" }
        let pageVerses = pages[min(currentPage, pages.count - 1)]
        let pageNum = pageVerses.first?.page ?? 0
        return "Page \(pageNum)"
    }
}
