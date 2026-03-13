import Testing
@testable import Niya

struct TafsirBlockParserTests {

    // MARK: - Quote Group

    @Test func arabicFollowedByParenTranslationProducesQuoteGroup() {
        let text = """
        بِسْمِ اللَّهِ الرَّحْمَـنِ الرَّحِيمِ
        (In the Name of Allah, the Most Gracious, the Most Merciful.)
        """
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .quoteGroup(let arabic, let translation) = blocks.first else {
            Issue.record("Expected quoteGroup")
            return
        }
        #expect(arabic.contains("بِسْمِ"))
        #expect(translation.contains("In the Name"))
    }

    // MARK: - Standalone Arabic

    @Test func arabicWithoutFollowingParenIsStandalone() {
        let text = """
        بِسْمِ اللَّهِ الرَّحْمَـنِ الرَّحِيمِ
        This is a regular commentary line.
        """
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 2)
        guard case .arabicQuote = blocks[0] else {
            Issue.record("Expected arabicQuote")
            return
        }
        guard case .commentary = blocks[1] else {
            Issue.record("Expected commentary")
            return
        }
    }

    // MARK: - Heading

    @Test func shortEnglishTitleIsHeading() {
        let text = "The Virtue of Al-Fatihah"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .heading = blocks.first else {
            Issue.record("Expected heading")
            return
        }
    }

    // MARK: - Heading exclusions

    @Test func shortEnglishEndingInCommaIsCommentary() {
        let text = "He said to them,"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary, not heading")
            return
        }
    }

    @Test func shortEnglishEndingInSemicolonIsCommentary() {
        let text = "There are several views on this;"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary")
            return
        }
    }

    @Test func shortEnglishEndingInColonIsCommentary() {
        let text = "The scholars said:"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary")
            return
        }
    }

    // MARK: - Translation after English is commentary

    @Test func parenAfterEnglishIsCommentary() {
        let text = """
        This is a commentary line.
        (This is not a translation)
        """
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 2)
        guard case .commentary = blocks[0] else {
            Issue.record("Expected commentary")
            return
        }
        guard case .commentary = blocks[1] else {
            Issue.record("Expected commentary for paren after English")
            return
        }
    }

    // MARK: - Mixed Arabic/English is commentary

    @Test func mixedArabicEnglishIsCommentary() {
        let text = "The word الرَّحْمَـنِ means the Most Gracious"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary for mixed line")
            return
        }
    }

    // MARK: - Multiple consecutive Arabic lines

    @Test func multipleConsecutiveArabicLinesAreEachStandalone() {
        let text = """
        بِسْمِ اللَّهِ الرَّحْمَـنِ الرَّحِيمِ
        الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ
        Some commentary here.
        """
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 3)
        guard case .arabicQuote = blocks[0] else {
            Issue.record("Expected arabicQuote for first line")
            return
        }
        guard case .arabicQuote = blocks[1] else {
            Issue.record("Expected arabicQuote for second line")
            return
        }
        guard case .commentary = blocks[2] else {
            Issue.record("Expected commentary")
            return
        }
    }

    // MARK: - Narrator keywords prevent heading

    @Test func lineWithNarratorKeywordsIsCommentary() {
        let text = "Ibn Abbas said that this verse"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary for narrator line")
            return
        }
    }

    @Test func lineWithNarratedIsCommentary() {
        let text = "Abu Hurayrah narrated this hadith"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary")
            return
        }
    }

    // MARK: - Long English is commentary

    @Test func longEnglishLineIsCommentary() {
        let longLine = String(repeating: "This is a very long commentary line that goes on. ", count: 3)
        let blocks = TafsirBlockParser.parse(longLine)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary for long line")
            return
        }
    }

    // MARK: - Lowercase start is commentary

    @Test func lowercaseStartIsCommentary() {
        let text = "meaning that he was correct"
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 1)
        guard case .commentary = blocks.first else {
            Issue.record("Expected commentary for lowercase line")
            return
        }
    }

    // MARK: - Empty input

    @Test func emptyInputProducesNoBlocks() {
        let blocks = TafsirBlockParser.parse("")
        #expect(blocks.isEmpty)
    }

    @Test func whitespaceOnlyInputProducesNoBlocks() {
        let blocks = TafsirBlockParser.parse("   \n   \n   ")
        #expect(blocks.isEmpty)
    }

    // MARK: - Full passage integration

    @Test func fullPassageProducesCorrectBlockTypes() {
        let text = """
        The Meaning of Al-Fatihah

        بِسْمِ اللَّهِ الرَّحْمَـنِ الرَّحِيمِ
        (In the Name of Allah, the Most Gracious, the Most Merciful.)

        This Surah is called Al-Fatihah because it opens the Book.
        """
        let blocks = TafsirBlockParser.parse(text)
        #expect(blocks.count == 3)
        guard case .heading = blocks[0] else {
            Issue.record("Expected heading")
            return
        }
        guard case .quoteGroup = blocks[1] else {
            Issue.record("Expected quoteGroup")
            return
        }
        guard case .commentary = blocks[2] else {
            Issue.record("Expected commentary")
            return
        }
    }
}
