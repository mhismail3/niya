import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("AudioService Extensions")
struct AudioServiceTests {

    // MARK: - Playback speed

    @Test func playbackRateDefaultsToNormalSpeed() {
        #expect(AudioService.isolated().playbackRate == 1.0)
    }

    @Test func setRateClampsToSupportedRange() {
        let service = AudioService.isolated()
        service.setRate(0.1)
        #expect(service.playbackRate == PlaybackSpeed.range.lowerBound)
        service.setRate(9)
        #expect(service.playbackRate == PlaybackSpeed.range.upperBound)
        service.setRate(.nan)
        #expect(service.playbackRate == 1.0)
    }

    @Test func playbackRatePersistsAcrossLaunches() throws {
        let defaults = try #require(UserDefaults(suiteName: "niya-tests-\(UUID().uuidString)"))
        AudioService(defaults: defaults).setRate(1.75)
        #expect(AudioService(defaults: defaults).playbackRate == 1.75)
    }

    @Test func setRateNeverStartsPlayback() {
        let service = AudioService.isolated()
        service.setRate(1.5)
        #expect(service.isPlaying == false)
    }

    @Test func everyOfferedSpeedIsWithinRangeAndIncludesNormal() {
        #expect(PlaybackSpeed.options.contains(1.0))
        #expect(PlaybackSpeed.options.allSatisfy { PlaybackSpeed.range.contains($0) })
        #expect(PlaybackSpeed.options == PlaybackSpeed.options.sorted())
    }

    @Test func currentTimeMsDefaultsToZero() {
        let service = AudioService.isolated()
        #expect(service.currentTimeMs == 0)
    }

    @Test func isFollowAlongActiveDefaultsFalse() {
        let service = AudioService.isolated()
        #expect(service.isFollowAlongActive == false)
    }

    @Test func stopResetsFollowAlong() {
        let service = AudioService.isolated()
        service.isFollowAlongActive = true
        service.stop()
        #expect(service.isFollowAlongActive == false)
    }

    @Test func initialPlayingState() {
        let service = AudioService.isolated()
        #expect(service.isPlaying == false)
        #expect(service.isLoading == false)
    }

    @Test func streamURLReturnsNilForNoreen() {
        let service = AudioService.isolated()
        let url = service.streamURL(absoluteVerseNumber: 1, reciter: .noreenSiddiq)
        #expect(url == nil)
    }

    @Test func streamURLReturnsURLForAlAfasy() {
        let service = AudioService.isolated()
        let url = service.streamURL(absoluteVerseNumber: 7, reciter: .alAfasy)
        #expect(url != nil)
        #expect(url!.absoluteString == "https://cdn.islamic.network/quran/audio/128/ar.alafasy/7.mp3")
    }

    @Test func surahStreamURLUsesReciter() {
        let service = AudioService.isolated()
        let alAfasy = service.surahStreamURL(surahId: 36, reciter: .alAfasy)
        let noreen = service.surahStreamURL(surahId: 36, reciter: .noreenSiddiq)
        #expect(alAfasy != noreen)
    }

    @Test func streamURLReturnsNilForBukhatir() {
        let service = AudioService.isolated()
        let url = service.streamURL(absoluteVerseNumber: 1, reciter: .bukhatir)
        #expect(url == nil)
    }

    @Test func bukhatirSurahStreamURLDiffersFromNoreen() {
        let service = AudioService.isolated()
        let bukhatir = service.surahStreamURL(surahId: 36, reciter: .bukhatir)
        let noreen = service.surahStreamURL(surahId: 36, reciter: .noreenSiddiq)
        #expect(bukhatir != noreen)
        #expect(bukhatir.absoluteString.contains("salaah_bukhaatir"))
    }
}
