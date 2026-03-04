import Foundation

@MainActor protocol WordDataProviding: AnyObject {
    var isLoaded: Bool { get }
    var currentReciter: Reciter? { get }
    func load(reciter: Reciter) async
    func words(surahId: Int, ayahId: Int) -> VerseWordData?
    func allVerseData(surahId: Int) -> [(ayahId: Int, data: VerseWordData)]?
}
