import Foundation
@testable import Niya

@MainActor
final class MockWordDataService: WordDataProviding {
    var isLoaded = false
    var currentReciter: Reciter?

    var loadCallCount = 0
    var wordsResult: [String: VerseWordData] = [:]
    var allVerseDataResult: [(ayahId: Int, data: VerseWordData)]?

    func load(reciter: Reciter) async {
        loadCallCount += 1
        currentReciter = reciter
        isLoaded = true
    }

    func words(surahId: Int, ayahId: Int) -> VerseWordData? {
        wordsResult["\(surahId):\(ayahId)"]
    }

    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]? {
        allVerseDataResult
    }
}
