import Foundation

@MainActor protocol WordDataProviding: AnyObject {
    var isLoaded: Bool { get }
    var currentReciter: Reciter? { get }
    var currentMeaningLanguage: String? { get }
    func load(reciter: Reciter) async
    func loadMeanings(language: String) async
    func words(surahId: Int, ayahId: Int) -> VerseWordData?
    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]?
}
