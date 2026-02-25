import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("ReadingPosition Model")
struct ReadingPositionModelTests {

    @Test func createReadingPosition() {
        let now = Date.now
        let position = ReadingPosition(surahId: 2, lastAyahId: 50, lastReadAt: now)

        #expect(position.surahId == 2)
        #expect(position.lastAyahId == 50)
        #expect(position.lastReadAt == now)
    }

    @Test func defaultDate() {
        let before = Date.now
        let position = ReadingPosition(surahId: 1, lastAyahId: 1)
        let after = Date.now

        #expect(position.lastReadAt >= before)
        #expect(position.lastReadAt <= after)
    }

    @Test func fieldsAreMutable() {
        let position = ReadingPosition(surahId: 1, lastAyahId: 5)
        position.lastAyahId = 20
        position.lastReadAt = Date.distantPast

        #expect(position.lastAyahId == 20)
        #expect(position.lastReadAt == Date.distantPast)
    }
}
