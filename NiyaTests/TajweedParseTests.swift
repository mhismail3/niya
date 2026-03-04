import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("Tajweed Markup Parser")
struct TajweedParseTests {

    private let service = TajweedService()

    @Test func plainTextNoMarkup() {
        let result = service.parseTajweedMarkup("بِسْمِ اللَّهِ", ayahId: 1)
        #expect(result.text == "بِسْمِ اللَّهِ")
        #expect(result.annotations.isEmpty)
    }

    @Test func singleAnnotation() {
        let result = service.parseTajweedMarkup("[h[بِسْمِ]", ayahId: 1)
        #expect(result.text == "بِسْمِ")
        #expect(result.annotations.count == 1)
        #expect(result.annotations[0].rule == .hamzatWasl)
        #expect(result.annotations[0].start == 0)
        #expect(result.annotations[0].end == "بِسْمِ".count)
    }

    @Test func multipleAnnotations() {
        let result = service.parseTajweedMarkup("[h[بِسْ][g[مِ]", ayahId: 1)
        #expect(result.annotations.count == 2)
        #expect(result.annotations[0].rule == .hamzatWasl)
        #expect(result.annotations[0].start == 0)
        #expect(result.annotations[0].end == "بِسْ".count)
        #expect(result.annotations[1].rule == .ghunnah)
        #expect(result.annotations[1].start == "بِسْ".count)
        #expect(result.annotations[1].end == "بِسْمِ".count)
    }

    @Test func bomStripping() {
        let result = service.parseTajweedMarkup("\u{FEFF}text", ayahId: 1)
        #expect(!result.text.hasPrefix("\u{FEFF}"))
        #expect(result.text == "text")
    }

    @Test func emptyMarkup() {
        let result = service.parseTajweedMarkup("", ayahId: 1)
        #expect(result.text.isEmpty)
        #expect(result.annotations.isEmpty)
    }

    @Test func mixedAnnotatedAndPlainText() {
        let result = service.parseTajweedMarkup("plain [h[annotated] more", ayahId: 1)
        #expect(result.text == "plain annotated more")
        #expect(result.annotations.count == 1)
        #expect(result.annotations[0].rule == .hamzatWasl)
        #expect(result.annotations[0].start == "plain ".count)
        #expect(result.annotations[0].end == "plain annotated".count)
    }

    @Test func allTajweedRules() {
        let expectedMappings: [(String, TajweedRule)] = [
            ("h", .hamzatWasl),
            ("l", .lamShamsiyyah),
            ("n", .maddNormal),
            ("p", .maddPermissible),
            ("o", .maddObligatory),
            ("m", .maddNecessary),
            ("g", .ghunnah),
            ("q", .qalqalah),
            ("s", .silent),
            ("f", .ikhfa),
            ("a", .idghamGhunnah),
            ("u", .idghamNoGhunnah),
            ("i", .iqlab),
            ("c", .ikhfaShafawi),
            ("d", .tafkheem),
            ("w", .izharShafawi),
        ]

        for (tag, expectedRule) in expectedMappings {
            let markup = "[\(tag)[x]"
            let result = service.parseTajweedMarkup(markup, ayahId: 1)
            #expect(result.annotations.count == 1, "Tag '\(tag)' should produce one annotation")
            #expect(result.annotations[0].rule == expectedRule, "Tag '\(tag)' should map to \(expectedRule)")
        }
    }
}
