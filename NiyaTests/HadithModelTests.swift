import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("Hadith Models")
struct HadithModelTests {

    @Test func hadithCollectionDecoding() throws {
        let json = """
        {"id":"bukhari","name":"Sahih al-Bukhari","nameArabic":"صحيح البخاري",
         "author":"Imam al-Bukhari","totalHadiths":7563,"totalChapters":97,"hasGrades":true}
        """.data(using: .utf8)!
        let collection = try JSONDecoder().decode(HadithCollection.self, from: json)
        #expect(collection.id == "bukhari")
        #expect(collection.name == "Sahih al-Bukhari")
        #expect(collection.nameArabic == "صحيح البخاري")
        #expect(collection.author == "Imam al-Bukhari")
        #expect(collection.totalHadiths == 7563)
        #expect(collection.totalChapters == 97)
        #expect(collection.hasGrades == true)
    }

    @Test func hadithChapterCount() {
        let chapter = HadithChapter(id: 1, title: "Revelation", titleArabic: "بدء الوحي", hadithRange: [1, 7])
        #expect(chapter.hadithCount == 7)
    }

    @Test func hadithChapterCountEmptyRange() {
        let chapter = HadithChapter(id: 1, title: "Test", titleArabic: "اختبار", hadithRange: [])
        #expect(chapter.hadithCount == 0)
    }

    @Test func hadithDecodingWithGrade() throws {
        let json = """
        {"id":1,"chapterId":1,"arabic":"حدثنا","narrator":"Narrated by","text":"The Prophet said",
         "grade":"Sahih","gradeArabic":"صحيح"}
        """.data(using: .utf8)!
        let hadith = try JSONDecoder().decode(Hadith.self, from: json)
        #expect(hadith.id == 1)
        #expect(hadith.chapterId == 1)
        #expect(hadith.grade == "Sahih")
        #expect(hadith.gradeArabic == "صحيح")
    }

    @Test func hadithDecodingWithoutGrade() throws {
        let json = """
        {"id":1,"chapterId":1,"arabic":"حدثنا","narrator":"Narrated by","text":"The Prophet said",
         "grade":null,"gradeArabic":null}
        """.data(using: .utf8)!
        let hadith = try JSONDecoder().decode(Hadith.self, from: json)
        #expect(hadith.grade == nil)
        #expect(hadith.gradeArabic == nil)
    }

    @Test func gradeFromSahih() {
        #expect(HadithGrade.from("Sahih") == .sahih)
    }

    @Test func gradeFromHasanSahih() {
        #expect(HadithGrade.from("Hasan Sahih") == .sahih)
    }

    @Test func gradeFromDaif() {
        #expect(HadithGrade.from("Da'if") == .daif)
    }

    @Test func gradeFromDaifAltSpelling() {
        #expect(HadithGrade.from("Daif") == .daif)
    }

    @Test func gradeFromNil() {
        #expect(HadithGrade.from(nil) == nil)
    }

    @Test func gradeFromUnknownString() {
        #expect(HadithGrade.from("some unknown") == nil)
    }

    @Test func gradeColors() {
        #expect(HadithGrade.sahih.color == .niyaTeal)
        #expect(HadithGrade.hasan.color == .niyaGold)
        #expect(HadithGrade.daif.color == .niyaSecondary)
    }

    @Test func hadithBookmarkKey() {
        let bookmark = HadithBookmark(collectionId: "bukhari", hadithId: 1)
        #expect(bookmark.hadithKey == "bukhari:1")
    }

    @Test func hadithCollectionHashable() {
        let a = HadithCollection(id: "bukhari", name: "Sahih al-Bukhari", nameArabic: "صحيح البخاري", author: "Imam al-Bukhari", totalHadiths: 7563, totalChapters: 97, hasGrades: true)
        let b = HadithCollection(id: "bukhari", name: "Sahih al-Bukhari", nameArabic: "صحيح البخاري", author: "Imam al-Bukhari", totalHadiths: 7563, totalChapters: 97, hasGrades: true)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
