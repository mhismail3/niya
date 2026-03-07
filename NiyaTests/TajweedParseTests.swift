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

    // MARK: - Nested Tag Tests

    @Test func nestedSingleLevel() {
        // [o[[s[و]ٲٓاْ] — obligatory madd wrapping a silent letter
        let result = service.parseTajweedMarkup("[o[[s[و]ٲٓاْ]", ayahId: 1)
        #expect(result.text == "وٲٓاْ")
        #expect(!result.text.contains("["))
        #expect(!result.text.contains("]"))
        #expect(result.annotations.count == 2)
        // Inner: silent on "و"
        let silent = result.annotations.first { $0.rule == .silent }!
        #expect(silent.start == 0)
        #expect(silent.end == "و".count)
        // Outer: obligatory on full span "وٲٓاْ"
        let obligatory = result.annotations.first { $0.rule == .maddObligatory }!
        #expect(obligatory.start == 0)
        #expect(obligatory.end == "وٲٓاْ".count)
    }

    @Test func nestedDeep() {
        // [h[[o[[s[x]y]z] — 3 levels deep
        let result = service.parseTajweedMarkup("[h[[o[[s[x]y]z]", ayahId: 1)
        #expect(result.text == "xyz")
        #expect(result.annotations.count == 3)
        let silent = result.annotations.first { $0.rule == .silent }!
        #expect(silent.start == 0)
        #expect(silent.end == 1)
        let obligatory = result.annotations.first { $0.rule == .maddObligatory }!
        #expect(obligatory.start == 0)
        #expect(obligatory.end == 2)
        let hamzat = result.annotations.first { $0.rule == .hamzatWasl }!
        #expect(hamzat.start == 0)
        #expect(hamzat.end == 3)
    }

    @Test func nestedAdjacentInner() {
        // [o[[s[و][g[ن]ا] — two inner tags inside one outer
        let result = service.parseTajweedMarkup("[o[[s[و][g[ن]ا]", ayahId: 1)
        #expect(result.text == "ونا")
        #expect(!result.text.contains("["))
        #expect(result.annotations.count == 3)
        let silent = result.annotations.first { $0.rule == .silent }!
        #expect(silent.start == 0)
        #expect(silent.end == "و".count)
        let ghunnah = result.annotations.first { $0.rule == .ghunnah }!
        #expect(ghunnah.start == "و".count)
        #expect(ghunnah.end == "ون".count)
        let obligatory = result.annotations.first { $0.rule == .maddObligatory }!
        #expect(obligatory.start == 0)
        #expect(obligatory.end == "ونا".count)
    }

    @Test func nestedWithModifier() {
        // [h:541[[s[اْ]text] — outer has :541 modifier
        let result = service.parseTajweedMarkup("[h:541[[s[اْ]text]", ayahId: 1)
        #expect(result.text == "اْtext")
        #expect(result.annotations.count == 2)
        let silent = result.annotations.first { $0.rule == .silent }!
        #expect(silent.start == 0)
        #expect(silent.end == "اْ".count)
        let hamzat = result.annotations.first { $0.rule == .hamzatWasl }!
        #expect(hamzat.start == 0)
        #expect(hamzat.end == "اْtext".count)
    }

    // MARK: - Stop Mark Tests

    @Test func stopMarkStrippedPlain() {
        let result = service.parseTajweedMarkup("text\u{06D6}more", ayahId: 1)
        #expect(result.text == "textmore")
        #expect(result.annotations.isEmpty)
    }

    @Test func stopMarkStrippedInsideTag() {
        let result = service.parseTajweedMarkup("[h[text\u{06D6}]", ayahId: 1)
        #expect(result.text == "text")
        #expect(result.annotations.count == 1)
        #expect(result.annotations[0].rule == .hamzatWasl)
        #expect(result.annotations[0].start == 0)
        #expect(result.annotations[0].end == "text".count)
    }

    @Test func stopMarkStripsRubElHizb() {
        // U+06DE (Rub El Hizb ۞) stripped — KFGQPC font lacks glyph for it
        let result = service.parseTajweedMarkup("\u{06DE}text", ayahId: 1)
        #expect(result.text == "text")
    }

    @Test func stopMarkOffsetsCorrect() {
        // [h[a\u{06D6}b][g[c] — mark inside tag, offsets should skip the mark
        let result = service.parseTajweedMarkup("[h[a\u{06D6}b][g[c]", ayahId: 1)
        #expect(result.text == "abc")
        #expect(result.annotations.count == 2)
        let hamzat = result.annotations.first { $0.rule == .hamzatWasl }!
        #expect(hamzat.start == 0)
        #expect(hamzat.end == 2) // "ab"
        let ghunnah = result.annotations.first { $0.rule == .ghunnah }!
        #expect(ghunnah.start == 2)
        #expect(ghunnah.end == 3) // "c"
    }

    @Test func allUnsupportedMarksStripped() {
        let marks: [UInt32] = [
            0x06D6, 0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC,
            0x06DD, 0x06DE,
            0x06E9,
            0x06EA, 0x06EB, 0x06EC, 0x06ED,
        ]
        for code in marks {
            let scalar = Unicode.Scalar(code)!
            let input = "a\(scalar)b"
            let result = service.parseTajweedMarkup(input, ayahId: 1)
            #expect(result.text == "ab", "U+\(String(code, radix: 16, uppercase: true)) should be stripped")
        }
    }

    // MARK: - Real API Pattern Tests

    @Test func realVerse3_130() {
        // Simplified pattern from Ali 'Imran 130 containing nested tags
        let markup = "رِّبَ[o[[s[وٰ]ٲٓاْ]"
        let result = service.parseTajweedMarkup(markup, ayahId: 130)
        #expect(!result.text.contains("["))
        #expect(!result.text.contains("]"))
        #expect(result.text.hasPrefix("رِّبَ"))
        #expect(result.text.contains("وٰ"))
    }

    @Test func realVerse3_64() {
        // Pattern with stop mark
        let markup = "سَوَآءٍ\u{06DA} بَيْنَنَا"
        let result = service.parseTajweedMarkup(markup, ayahId: 64)
        #expect(!result.text.contains("\u{06DA}"))
        #expect(result.text == "سَوَآءٍ بَيْنَنَا")
    }

    // MARK: - Edge Case / Regression Tests

    @Test func emptyNestedTag() {
        // [o[[s[]]] — empty inner tag content
        let result = service.parseTajweedMarkup("[o[[s[]]", ayahId: 1)
        // Should not crash; inner annotation has start == end
        #expect(!result.text.contains("["))
    }

    @Test func malformedUnclosedNested() {
        // [o[[s[text] — outer tag missing closing bracket
        let result = service.parseTajweedMarkup("[o[[s[text]", ayahId: 1)
        // Inner tag should be parsed, outer degrades gracefully
        #expect(result.text.contains("text"))
        #expect(!result.text.contains("["))
    }

    @Test func standaloneCloseBracket() {
        // Literal ] outside a tag should be preserved
        let result = service.parseTajweedMarkup("text]more", ayahId: 1)
        #expect(result.text == "text]more")
    }

    @Test func tagWithModifierNoNesting() {
        // [h:541[ٱ] — modifier without nesting (existing behavior)
        let result = service.parseTajweedMarkup("[h:541[ٱ]", ayahId: 1)
        #expect(result.text == "ٱ")
        #expect(result.annotations.count == 1)
        #expect(result.annotations[0].rule == .hamzatWasl)
    }

    @Test func unknownTagLetterStillExtractsText() {
        // [z[text] — 'z' is not a known rule
        let result = service.parseTajweedMarkup("[z[text]", ayahId: 1)
        #expect(result.text == "text")
        #expect(result.annotations.isEmpty)
    }
}
