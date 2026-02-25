import Foundation
import AVFoundation

struct VerseID: Hashable, Sendable {
    let surahId: Int
    let ayahId: Int
}

@Observable
@MainActor
final class AudioService {
    var isPlaying = false
    var isLoading = false
    var currentVerseID: VerseID?
    var currentSurahId: Int?
    var downloadProgress: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioService] Session config error: \(error)")
        }
    }

    func play(url: URL, verseID: VerseID? = nil, surahId: Int? = nil) {
        stop()
        isLoading = true
        currentVerseID = verseID
        currentSurahId = surahId

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        player?.play()
        isPlaying = true
        isLoading = false
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentVerseID = nil
        currentSurahId = nil
    }

    func togglePause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func streamURL(absoluteVerseNumber: Int) -> URL {
        URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(absoluteVerseNumber).mp3")!
    }

    func surahStreamURL(surahId: Int) -> URL {
        URL(string: "https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/\(surahId).mp3")!
    }

    func localSurahURL(surahId: Int) -> URL? {
        let filename = localFilename(for: surahId)
        let url = documentsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func downloadSurah(surahId: Int) async throws -> URL {
        let remote = surahStreamURL(surahId: surahId)
        let localURL = documentsDirectory.appendingPathComponent(localFilename(for: surahId))

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        downloadProgress = 0
        let (tempURL, _) = try await URLSession.shared.download(from: remote)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        downloadProgress = 1
        return localURL
    }

    func localFilename(for surahId: Int) -> String {
        "audio_surah_\(surahId).mp3"
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @objc private func playerDidFinish() {
        isPlaying = false
        currentVerseID = nil
        currentSurahId = nil
    }
}
