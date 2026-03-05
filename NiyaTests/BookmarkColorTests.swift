import Testing
import Foundation
@testable import Niya

// MARK: - BookmarkColor Enum

@Suite("BookmarkColor Enum")
struct BookmarkColorEnumTests {
    @Test func allCasesCountIsFour() {
        #expect(BookmarkColor.allCases.count == 4)
    }

    @Test func rawValueRoundTrip() {
        for bc in BookmarkColor.allCases {
            #expect(BookmarkColor(rawValue: bc.rawValue) == bc)
        }
    }

    @Test func displayNameIsNotEmpty() {
        for bc in BookmarkColor.allCases {
            #expect(!bc.displayName.isEmpty)
        }
    }

    @Test func identifiableIdMatchesRawValue() {
        for bc in BookmarkColor.allCases {
            #expect(bc.id == bc.rawValue)
        }
    }

    @Test func codableRoundTrip() throws {
        for bc in BookmarkColor.allCases {
            let data = try JSONEncoder().encode(bc)
            let decoded = try JSONDecoder().decode(BookmarkColor.self, from: data)
            #expect(decoded == bc)
        }
    }
}

// MARK: - Bookmark Model ColorTag

@Suite("Bookmark Model ColorTag")
struct BookmarkModelColorTagTests {
    @Test func quranBookmarkNilTagReturnsNil() {
        let b = QuranBookmark(surahId: 1, ayahId: 1)
        #expect(b.bookmarkColor == nil)
    }

    @Test func quranBookmarkValidTagReturnsColor() {
        let b = QuranBookmark(surahId: 1, ayahId: 1)
        b.colorTag = "emerald"
        #expect(b.bookmarkColor == .emerald)
    }

    @Test func quranBookmarkInvalidTagReturnsNil() {
        let b = QuranBookmark(surahId: 1, ayahId: 1)
        b.colorTag = "invalid"
        #expect(b.bookmarkColor == nil)
    }

    @Test func quranBookmarkEmptyStringTagReturnsNil() {
        let b = QuranBookmark(surahId: 1, ayahId: 1)
        b.colorTag = ""
        #expect(b.bookmarkColor == nil)
    }

    @Test func quranBookmarkSetterWritesRawValue() {
        let b = QuranBookmark(surahId: 1, ayahId: 1)
        b.bookmarkColor = .sapphire
        #expect(b.colorTag == "sapphire")
    }

    @Test func quranBookmarkSetterNilClearsTag() {
        let b = QuranBookmark(surahId: 1, ayahId: 1)
        b.bookmarkColor = .rose
        b.bookmarkColor = nil
        #expect(b.colorTag == nil)
    }

    @Test func hadithBookmarkColorTagWorks() {
        let b = HadithBookmark(collectionId: "bukhari", hadithId: 1)
        #expect(b.bookmarkColor == nil)
        b.bookmarkColor = .plum
        #expect(b.colorTag == "plum")
        #expect(b.bookmarkColor == .plum)
    }

    @Test func duaBookmarkColorTagWorks() {
        let b = DuaBookmark(categoryId: 1, duaId: 1)
        #expect(b.bookmarkColor == nil)
        b.bookmarkColor = .emerald
        #expect(b.colorTag == "emerald")
        #expect(b.bookmarkColor == .emerald)
    }

    @Test func existingBookmarksDefaultToNilColor() {
        let q = QuranBookmark(surahId: 2, ayahId: 255)
        let h = HadithBookmark(collectionId: "muslim", hadithId: 42)
        let d = DuaBookmark(categoryId: 3, duaId: 7)
        #expect(q.bookmarkColor == nil)
        #expect(h.bookmarkColor == nil)
        #expect(d.bookmarkColor == nil)
    }
}

// MARK: - ColorFilter Logic

@Suite("BookmarksView ColorFilter")
struct BookmarkColorFilterTests {
    private func makeQuranBookmarks() -> [QuranBookmark] {
        let b1 = QuranBookmark(surahId: 1, ayahId: 1)
        let b2 = QuranBookmark(surahId: 2, ayahId: 1)
        b2.bookmarkColor = .emerald
        let b3 = QuranBookmark(surahId: 3, ayahId: 1)
        b3.bookmarkColor = .sapphire
        return [b1, b2, b3]
    }

    private func filtered(_ bookmarks: [QuranBookmark], color: BookmarkColor??) -> [QuranBookmark] {
        guard let filter = color else { return bookmarks }
        return bookmarks.filter { $0.bookmarkColor == filter }
    }

    @Test func colorFilterAllMatchesEverything() {
        let bookmarks = makeQuranBookmarks()
        let result = filtered(bookmarks, color: nil)
        #expect(result.count == 3)
    }

    @Test func colorFilterNilMatchesDefaultBookmarks() {
        let bookmarks = makeQuranBookmarks()
        let result = filtered(bookmarks, color: .some(nil))
        #expect(result.count == 1)
        #expect(result.first?.surahId == 1)
    }

    @Test func colorFilterSpecificMatchesOnlyThat() {
        let bookmarks = makeQuranBookmarks()
        let result = filtered(bookmarks, color: .some(.emerald))
        #expect(result.count == 1)
        #expect(result.first?.surahId == 2)
    }

    @Test func colorFilterMismatchReturnsEmpty() {
        let bookmarks = makeQuranBookmarks()
        let result = filtered(bookmarks, color: .some(.plum))
        #expect(result.isEmpty)
    }

    @Test func mixedColorsFilterCorrectly() {
        let bookmarks = makeQuranBookmarks()
        let emeralds = filtered(bookmarks, color: .some(.emerald))
        let sapphires = filtered(bookmarks, color: .some(.sapphire))
        let defaults = filtered(bookmarks, color: .some(nil))
        #expect(emeralds.count == 1)
        #expect(sapphires.count == 1)
        #expect(defaults.count == 1)
    }
}
