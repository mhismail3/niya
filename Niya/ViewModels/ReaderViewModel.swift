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

    let surah: Surah
    private let dataService: QuranDataService

    var verses: [Verse] = []
    var pages: [[Verse]] = []

    init(surah: Surah, dataService: QuranDataService, script: QuranScript, showTranslation: Bool) {
        self.surah = surah
        self.dataService = dataService
        self.script = script
        self.showTranslation = showTranslation
    }

    func load() {
        verses = dataService.verses(for: surah.id, script: script)
        pages = dataService.pages(for: surah.id, script: script)
        currentPage = 0
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
