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
}
