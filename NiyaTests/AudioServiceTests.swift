import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("AudioService Extensions")
struct AudioServiceTests {

    @Test func currentTimeMsDefaultsToZero() {
        let service = AudioService()
        #expect(service.currentTimeMs == 0)
    }

    @Test func isFollowAlongActiveDefaultsFalse() {
        let service = AudioService()
        #expect(service.isFollowAlongActive == false)
    }

    @Test func stopResetsFollowAlong() {
        let service = AudioService()
        service.isFollowAlongActive = true
        service.stop()
        #expect(service.isFollowAlongActive == false)
    }

    @Test func initialPlayingState() {
        let service = AudioService()
        #expect(service.isPlaying == false)
        #expect(service.isLoading == false)
    }

    @Test func streamURLReturnsNilForNoreen() {
        let service = AudioService()
        let url = service.streamURL(absoluteVerseNumber: 1, reciter: .noreenSiddiq)
        #expect(url == nil)
    }

    @Test func streamURLReturnsURLForAlAfasy() {
        let service = AudioService()
        let url = service.streamURL(absoluteVerseNumber: 7, reciter: .alAfasy)
        #expect(url != nil)
        #expect(url!.absoluteString == "https://cdn.islamic.network/quran/audio/128/ar.alafasy/7.mp3")
    }

    @Test func surahStreamURLUsesReciter() {
        let service = AudioService()
        let alAfasy = service.surahStreamURL(surahId: 36, reciter: .alAfasy)
        let noreen = service.surahStreamURL(surahId: 36, reciter: .noreenSiddiq)
        #expect(alAfasy != noreen)
    }
}
