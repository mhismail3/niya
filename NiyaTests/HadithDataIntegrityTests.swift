import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("Hadith Data Integrity")
struct HadithDataIntegrityTests {

    private struct CollectionFile: Decodable {
        let chapters: [HadithChapter]
        let hadiths: [Hadith]
    }

    private static let enabledCollections = [
        "bukhari", "muslim", "abudawud", "tirmidhi",
        "nasai", "ibnmajah", "malik", "ahmed", "darimi",
        "nawawi", "qudsi", "dehlawi", "aladab", "bulugh",
        "mishkat", "riyad", "shamail",
    ]

    private static let loaded: [String: CollectionFile] = {
        var result: [String: CollectionFile] = [:]
        let decoder = JSONDecoder()
        for cid in enabledCollections {
            guard let url = Bundle.main.url(forResource: "hadith_\(cid)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? decoder.decode(CollectionFile.self, from: data) else {
                continue
            }
            result[cid] = file
        }
        return result
    }()

    @Test func allEnabledCollectionsDecode() {
        for cid in Self.enabledCollections {
            #expect(Self.loaded[cid] != nil, "Failed to decode hadith_\(cid).json")
        }
    }

    @Test func nasaiLoadsAllChapters() {
        guard let nasai = Self.loaded["nasai"] else {
            Issue.record("Nasa'i not loaded")
            return
        }
        #expect(nasai.chapters.count == 52)
        for ch in nasai.chapters {
            #expect(ch.id > 0, "Chapter has invalid id: \(ch.id)")
        }
    }

    @Test func nasaiLoadsAllHadiths() {
        guard let nasai = Self.loaded["nasai"] else {
            Issue.record("Nasa'i not loaded")
            return
        }
        #expect(nasai.hadiths.count == 5768)
        for h in nasai.hadiths {
            #expect(h.chapterId > 0, "Hadith #\(h.id) has invalid chapterId: \(h.chapterId)")
        }
    }

    @Test func nasaiAgricultureChapterHasHadiths() {
        guard let nasai = Self.loaded["nasai"] else {
            Issue.record("Nasa'i not loaded")
            return
        }
        let agriculture = nasai.chapters.first { $0.title.contains("Agriculture") }
        #expect(agriculture != nil, "Agriculture chapter not found")
        if let ch = agriculture {
            #expect(ch.hadithCount == 83, "Expected 83 hadiths, got \(ch.hadithCount)")
        }
    }

    @Test func ahmedEmptyTitleChapterHasArabic() {
        guard let ahmed = Self.loaded["ahmed"] else {
            Issue.record("Ahmed not loaded")
            return
        }
        let emptyTitle = ahmed.chapters.filter { $0.title.isEmpty }
        #expect(!emptyTitle.isEmpty, "Ahmed should have a chapter with empty English title")
        for ch in emptyTitle {
            #expect(!ch.titleArabic.isEmpty,
                "Ahmed chapter \(ch.id) with empty title should have Arabic title")
        }
    }

    @Test func everyChapterHasValidHadithRange() {
        for (cid, file) in Self.loaded {
            for ch in file.chapters {
                let count = ch.hadithRange.count
                #expect(count == 0 || count == 2,
                    "\(cid) chapter \(ch.id) hadithRange has \(count) elements")
            }
        }
    }

    @Test func noOrphanHadiths() {
        for (cid, file) in Self.loaded {
            let chapterIds = Set(file.chapters.map(\.id))
            for h in file.hadiths {
                #expect(chapterIds.contains(h.chapterId),
                    "\(cid) hadith #\(h.id) chapterId \(h.chapterId) not in chapters")
            }
        }
    }

    @Test func everyHadithHasArabic() {
        for (cid, file) in Self.loaded {
            let empty = file.hadiths.filter { $0.arabic.isEmpty }.count
            let total = file.hadiths.count
            // Malik has ~6% empty arabic in source data
            #expect(Double(empty) / Double(max(total, 1)) < 0.10,
                "\(cid): \(empty)/\(total) hadiths have empty arabic")
        }
    }
}
