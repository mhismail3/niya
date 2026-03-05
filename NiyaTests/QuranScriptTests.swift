import Foundation
import UIKit
import Testing
@testable import Niya

@Suite("QuranScript")
struct QuranScriptTests {

    @Test func indoPakFontNameMatchesBundledFont() {
        let font = UIFont(name: QuranScript.indoPak.fontName, size: 24)
        #expect(font != nil, "IndoPak font '\(QuranScript.indoPak.fontName)' not found — not registered in Info.plist or missing from bundle")
    }

    @Test func hafsFontNameMatchesBundledFont() {
        let font = UIFont(name: QuranScript.hafs.fontName, size: 24)
        #expect(font != nil, "Hafs font '\(QuranScript.hafs.fontName)' not found")
    }

    @Test func allCasesHaveDisplayName() {
        for script in QuranScript.allCases {
            #expect(!script.displayName.isEmpty, "\(script.rawValue) has empty displayName")
        }
    }

    @Test func allCasesHaveFontSize() {
        for script in QuranScript.allCases {
            #expect(script.fontSize > 0, "\(script.rawValue) has fontSize <= 0")
        }
    }

    @Test func indoPakFontIsNotScheherazade() {
        #expect(QuranScript.indoPak.fontName != "ScheherazadeNew-Regular",
                "IndoPak font should no longer be Scheherazade")
    }

    @Test func fontRendersArabicText() {
        let fontName = QuranScript.indoPak.fontName
        guard let font = UIFont(name: fontName, size: 24) else {
            Issue.record("Font \(fontName) not available")
            return
        }
        // Verify the font's family name is not the system font fallback
        #expect(font.familyName != UIFont.systemFont(ofSize: 24).familyName,
                "IndoPak font fell back to system font")
    }
}
