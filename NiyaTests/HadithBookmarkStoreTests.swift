import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("HadithBookmark Model")
struct HadithBookmarkStoreTests {

    @Test func bookmarkCreation() {
        let bookmark = HadithBookmark(collectionId: "bukhari", hadithId: 42)
        #expect(bookmark.collectionId == "bukhari")
        #expect(bookmark.hadithId == 42)
    }

    @Test func bookmarkKeyComposite() {
        let bookmark = HadithBookmark(collectionId: "muslim", hadithId: 100)
        #expect(bookmark.hadithKey == "muslim:100")
    }

    @Test func bookmarkDefaultDate() {
        let before = Date.now
        let bookmark = HadithBookmark(collectionId: "bukhari", hadithId: 1)
        let after = Date.now
        #expect(bookmark.createdAt >= before)
        #expect(bookmark.createdAt <= after)
    }
}
