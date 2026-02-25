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
    var showTranslation: Bool
    var currentPage: Int = 0
    var initialAyahId: Int?
    var visibleAyahId: Int = 1
    var isSettled = false
    var hasUserScrolled = false

    let surah: Surah
    private let dataService: QuranDataService

    var verses: [Verse] = []
    var pages: [[Verse]] = []

    init(surah: Surah, dataService: QuranDataService, script: QuranScript, showTranslation: Bool, initialAyahId: Int? = nil) {
        self.surah = surah
        self.dataService = dataService
        self.script = script
        self.showTranslation = showTranslation
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

    func reloadForScript(_ newScript: QuranScript) {
        script = newScript
        load()
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
