import Foundation
import MediaPlayer

@Observable
@MainActor
final class AudioPlayerViewModel {
    var selectedReciter: Reciter
    var playbackSpeed: Float = 1.0
    var autoAdvance = true
    var loopCount: Int = 1
    private(set) var currentLoop = 0

    private let audioService: any AudioPlaying
    private let dataService: any QuranDataProviding
    private let wordDataService: any WordDataProviding
    private var _verseRevision = 0

    init(audioService: any AudioPlaying, dataService: any QuranDataProviding, wordDataService: any WordDataProviding, reciter: Reciter = .alAfasy) {
        self.audioService = audioService
        self.dataService = dataService
        self.wordDataService = wordDataService
        self.selectedReciter = reciter

        setupRemoteCommands()

        audioService.onVerseDidFinish = { [weak self] vid in
            guard let self else { return }
            self.currentLoop += 1
            if self.currentLoop < self.loopCount {
                self.startPlayback(surahId: vid.surahId, ayahId: vid.ayahId)
            } else {
                if self.loopCount > 1 {
                    self.loopCount = 1
                    self.currentLoop = 0
                }
                if self.autoAdvance {
                    let surah = self.dataService.surahs.first { $0.id == vid.surahId }
                    let nextAyah = vid.ayahId + 1
                    if let surah, nextAyah <= surah.totalVerses {
                        self.playVerse(surahId: vid.surahId, ayahId: nextAyah)
                    }
                } else {
                    self.clearNowPlaying()
                }
            }
        }

        audioService.onVerseDidChange = { [weak self] vid in
            guard let self else { return }
            self._verseRevision += 1
            self.updateNowPlaying()
        }
    }

    // MARK: - Remote Commands & Now Playing

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.audioService.resume()
                self.updateNowPlaying()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.audioService.pause()
                self.updateNowPlaying()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePause()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.nextVerse()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previousVerse()
            }
            return .success
        }
    }

    func updateNowPlaying() {
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()
        var info = nowPlayingCenter.nowPlayingInfo ?? [String: Any]()
        if let vid = audioService.currentVerseID {
            let surah = dataService.surahs.first { $0.id == vid.surahId }
            info[MPMediaItemPropertyTitle] = "Ayah \(vid.ayahId)"
            info[MPMediaItemPropertyAlbumTitle] = surah?.transliteration ?? "Surah \(vid.surahId)"
        } else if let surahId = audioService.currentSurahId {
            let surah = dataService.surahs.first { $0.id == surahId }
            info[MPMediaItemPropertyTitle] = surah?.transliteration ?? "Surah \(surahId)"
        }
        info[MPMediaItemPropertyArtist] = selectedReciter.displayName
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0.0
        nowPlayingCenter.nowPlayingInfo = info
        nowPlayingCenter.playbackState = isPlaying ? .playing : .paused
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    var isPlaying: Bool { audioService.isPlaying }
    var isLoading: Bool { audioService.isLoading }
    var currentVerseID: VerseID? {
        _ = _verseRevision
        return audioService.currentVerseID
    }
    var currentSurahId: Int? { audioService.currentSurahId }
    var isFollowAlongActive: Bool { audioService.isFollowAlongActive }
    var hasActiveSession: Bool { currentVerseID != nil || currentSurahId != nil || audioService.isFollowAlongActive }

    func playVerse(surahId: Int, ayahId: Int) {
        currentLoop = 0
        let verseID = VerseID(surahId: surahId, ayahId: ayahId)
        if autoAdvance && loopCount <= 1 {
            guard let allVerses = wordDataService.allVerseData(surahId: surahId) else {
                playVerseFallback(surahId: surahId, ayahId: ayahId, verseID: verseID)
                return
            }
            let boundaries = allVerses
                .filter { $0.ayahId >= ayahId }
                .map { VerseBoundary(verseID: VerseID(surahId: surahId, ayahId: $0.ayahId), startMs: $0.data.vs, endMs: $0.data.ve) }
            guard !boundaries.isEmpty,
                  let wordDataAudioURL = URL(string: allVerses[0].data.au) else { return }
            let url = continuousAudioURL(surahId: surahId, wordDataURL: wordDataAudioURL)
            audioService.playSurahContinuous(url: url, boundaries: boundaries, surahId: surahId)
            if playbackSpeed != 1.0 {
                audioService.setRate(playbackSpeed)
            }
        } else if selectedReciter.hasPerVerseAudio {
            let absNum = dataService.absoluteVerseNumber(surah: surahId, ayah: ayahId)
            guard let url = audioService.streamURL(absoluteVerseNumber: absNum, reciter: selectedReciter) else { return }
            audioService.play(url: url, verseID: verseID, surahId: surahId)
        } else {
            guard let verseData = wordDataService.words(surahId: surahId, ayahId: ayahId) else {
                playSurah(surahId)
                return
            }
            let url = audioService.localSurahURL(surahId: surahId, reciter: selectedReciter)
                ?? selectedReciter.surahStreamURL(surahId: surahId)
            audioService.playVerseInSurah(url: url, startMs: verseData.vs, endMs: verseData.ve, verseID: verseID, surahId: surahId)
        }
        updateNowPlaying()
    }

    /// Returns the audio URL for continuous mode, ensuring timing data matches the audio file.
    /// Uses local file only if it was downloaded from the same source as the word timing data.
    private func continuousAudioURL(surahId: Int, wordDataURL: URL) -> URL {
        let reciterURL = selectedReciter.surahStreamURL(surahId: surahId)
        if reciterURL.host == wordDataURL.host,
           let localURL = audioService.localSurahURL(surahId: surahId, reciter: selectedReciter) {
            return localURL
        }
        return wordDataURL
    }

    private func playVerseFallback(surahId: Int, ayahId: Int, verseID: VerseID) {
        if selectedReciter.hasPerVerseAudio {
            let absNum = dataService.absoluteVerseNumber(surah: surahId, ayah: ayahId)
            guard let url = audioService.streamURL(absoluteVerseNumber: absNum, reciter: selectedReciter) else { return }
            audioService.play(url: url, verseID: verseID, surahId: surahId)
        } else {
            playSurah(surahId)
        }
        updateNowPlaying()
    }

    func playSurah(_ surahId: Int) {
        if let localURL = audioService.localSurahURL(surahId: surahId, reciter: selectedReciter) {
            audioService.play(url: localURL, verseID: nil, surahId: surahId)
        } else {
            let url = audioService.surahStreamURL(surahId: surahId, reciter: selectedReciter)
            audioService.play(url: url, verseID: nil, surahId: surahId)
        }
        updateNowPlaying()
    }

    func stop() {
        audioService.stop()
        clearNowPlaying()
    }

    func togglePause() {
        audioService.togglePause()
        updateNowPlaying()
    }

    func setLoopCount(_ count: Int) {
        loopCount = count
        currentLoop = 0
        if let vid = currentVerseID, audioService.isPlaying {
            playVerse(surahId: vid.surahId, ayahId: vid.ayahId)
        }
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = min(max(speed, 0.5), 1.25)
        audioService.setRate(playbackSpeed)
        updateNowPlaying()
    }

    func previousVerse() {
        guard let vid = currentVerseID else { return }
        let prevAyah = vid.ayahId - 1
        guard prevAyah >= 1 else { return }
        if audioService.isContinuousMode,
           let verseData = wordDataService.words(surahId: vid.surahId, ayahId: prevAyah) {
            audioService.seekToVerse(VerseID(surahId: vid.surahId, ayahId: prevAyah), startMs: verseData.vs)
        } else {
            playVerse(surahId: vid.surahId, ayahId: prevAyah)
        }
        if playbackSpeed != 1.0 {
            audioService.setRate(playbackSpeed)
        }
        updateNowPlaying()
    }

    func nextVerse() {
        guard let vid = currentVerseID else { return }
        let surah = dataService.surahs.first { $0.id == vid.surahId }
        let nextAyah = vid.ayahId + 1
        guard let surah, nextAyah <= surah.totalVerses else { return }
        if audioService.isContinuousMode,
           let verseData = wordDataService.words(surahId: vid.surahId, ayahId: nextAyah) {
            audioService.seekToVerse(VerseID(surahId: vid.surahId, ayahId: nextAyah), startMs: verseData.vs)
        } else {
            playVerse(surahId: vid.surahId, ayahId: nextAyah)
        }
        if playbackSpeed != 1.0 {
            audioService.setRate(playbackSpeed)
        }
        updateNowPlaying()
    }

    func isPlayingVerse(surahId: Int, ayahId: Int) -> Bool {
        guard let vid = currentVerseID else { return false }
        return vid.surahId == surahId && vid.ayahId == ayahId
    }

    func isPlayingSurah(_ surahId: Int) -> Bool {
        audioService.currentSurahId == surahId && audioService.currentVerseID == nil
    }

    private func startPlayback(surahId: Int, ayahId: Int) {
        let verseID = VerseID(surahId: surahId, ayahId: ayahId)
        if selectedReciter.hasPerVerseAudio {
            let absNum = dataService.absoluteVerseNumber(surah: surahId, ayah: ayahId)
            guard let url = audioService.streamURL(absoluteVerseNumber: absNum, reciter: selectedReciter) else { return }
            audioService.transitionToVerse(url: url, verseID: verseID, surahId: surahId)
        } else {
            guard let verseData = wordDataService.words(surahId: surahId, ayahId: ayahId) else {
                playSurah(surahId)
                return
            }
            let url = audioService.localSurahURL(surahId: surahId, reciter: selectedReciter)
                ?? selectedReciter.surahStreamURL(surahId: surahId)
            audioService.playVerseInSurah(url: url, startMs: verseData.vs, endMs: verseData.ve, verseID: verseID, surahId: surahId)
        }
        if playbackSpeed != 1.0 {
            audioService.setRate(playbackSpeed)
        }
        updateNowPlaying()
    }
}
