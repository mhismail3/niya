import Foundation

@Observable
@MainActor
final class AudioPlayerViewModel {
    var downloadingSurahId: Int?
    var downloadError: String?
    var selectedReciter: Reciter

    private let audioService: AudioService
    private let dataService: QuranDataService
    private let wordDataService: WordDataService
    private var downloadStore: DownloadStore?

    init(audioService: AudioService, dataService: QuranDataService, wordDataService: WordDataService, reciter: Reciter = .alAfasy) {
        self.audioService = audioService
        self.dataService = dataService
        self.wordDataService = wordDataService
        self.selectedReciter = reciter
    }

    func setDownloadStore(_ store: DownloadStore) {
        self.downloadStore = store
    }

    var isPlaying: Bool { audioService.isPlaying }
    var isLoading: Bool { audioService.isLoading }
    var currentVerseID: VerseID? { audioService.currentVerseID }
    var currentSurahId: Int? { audioService.currentSurahId }
    var downloadProgress: Double { audioService.downloadProgress }
    var hasActiveSession: Bool { currentVerseID != nil || currentSurahId != nil }

    func playVerse(surahId: Int, ayahId: Int) {
        let verseID = VerseID(surahId: surahId, ayahId: ayahId)
        if selectedReciter.hasPerVerseAudio {
            let absNum = dataService.absoluteVerseNumber(surah: surahId, ayah: ayahId)
            guard let url = audioService.streamURL(absoluteVerseNumber: absNum, reciter: selectedReciter) else { return }
            audioService.play(url: url, verseID: verseID, surahId: surahId)
        } else {
            guard let verseData = wordDataService.words(surahId: surahId, ayahId: ayahId) else { return }
            let url = audioService.localSurahURL(surahId: surahId, reciter: selectedReciter)
                ?? selectedReciter.surahStreamURL(surahId: surahId)
            audioService.playVerseInSurah(url: url, startMs: verseData.vs, endMs: verseData.ve, verseID: verseID, surahId: surahId)
        }
    }

    func playSurah(_ surahId: Int) {
        if let localURL = audioService.localSurahURL(surahId: surahId, reciter: selectedReciter) {
            audioService.play(url: localURL, surahId: surahId)
        } else {
            let url = audioService.surahStreamURL(surahId: surahId, reciter: selectedReciter)
            audioService.play(url: url, surahId: surahId)
        }
    }

    func stop() {
        audioService.stop()
    }

    func togglePause() {
        audioService.togglePause()
    }

    func isPlayingVerse(surahId: Int, ayahId: Int) -> Bool {
        guard let vid = audioService.currentVerseID else { return false }
        return vid.surahId == surahId && vid.ayahId == ayahId
    }

    func isPlayingSurah(_ surahId: Int) -> Bool {
        audioService.currentSurahId == surahId && audioService.currentVerseID == nil
    }

    func downloadSurah(_ surahId: Int) async {
        downloadingSurahId = surahId
        downloadError = nil
        do {
            let localURL = try await audioService.downloadSurah(surahId: surahId, reciter: selectedReciter)
            try downloadStore?.save(surahId: surahId, filename: localURL.lastPathComponent, reciterId: selectedReciter.rawValue)
        } catch {
            downloadError = error.localizedDescription
        }
        downloadingSurahId = nil
    }

    func isDownloaded(_ surahId: Int) -> Bool {
        audioService.localSurahURL(surahId: surahId, reciter: selectedReciter) != nil
    }
}
