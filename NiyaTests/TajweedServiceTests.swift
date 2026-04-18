import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("TajweedService")
struct TajweedServiceTests {

    private func loadedService() async -> TajweedService {
        let service = TajweedService()
        await service.ensureLoaded()
        return service
    }

    @Test func allSurahsLoad() async {
        let service = await loadedService()
        for surahId in 1...114 {
            let verse = service.verse(surahId: surahId, ayahId: 1)
            #expect(verse != nil, "Surah \(surahId) ayah 1 should exist")
            #expect(!verse!.text.isEmpty, "Surah \(surahId) ayah 1 text should not be empty")
        }
    }

    @Test func annotationRangesWithinBounds() async {
        let service = await loadedService()
        for surahId in 1...114 {
            var ayahId = 1
            while let verse = service.verse(surahId: surahId, ayahId: ayahId) {
                let textLen = verse.text.count
                for ann in verse.annotations {
                    #expect(ann.start >= 0, "\(surahId):\(ayahId) start < 0")
                    #expect(ann.end <= textLen, "\(surahId):\(ayahId) end \(ann.end) > textLen \(textLen)")
                    #expect(ann.start < ann.end, "\(surahId):\(ayahId) start >= end")
                }
                ayahId += 1
            }
        }
    }

    @Test func knownVerseHasExpectedRules() async {
        let service = await loadedService()
        // Al-Fatiha ayah 1 should have annotations
        let verse = service.verse(surahId: 1, ayahId: 1)!
        #expect(!verse.annotations.isEmpty)
        let rules = Set(verse.annotations.map(\.rule))
        #expect(rules.contains(.hamzatWasl))
    }

    @Test func clearCacheAndReload() async {
        let service = await loadedService()
        _ = service.verse(surahId: 1, ayahId: 1)
        service.clearCache()
        // After clear, need to reload
        await service.ensureLoaded()
        let verse = service.verse(surahId: 1, ayahId: 1)
        #expect(verse != nil)
    }

    @Test func invalidSurahReturnsNil() async {
        let service = await loadedService()
        #expect(service.verse(surahId: 999, ayahId: 1) == nil)
    }

    @Test func lamJalalahAnnotated() async {
        let service = await loadedService()
        // Al-Fatiha 1:1 "بِسْمِ ٱللَّهِ" contains Allah
        let v1 = service.verse(surahId: 1, ayahId: 1)!
        let jRules1 = v1.annotations.filter { $0.rule == .lamJalalah }
        #expect(!jRules1.isEmpty, "1:1 should have Lam al-Jalalah annotation")

        // Al-Baqarah 2:7 "خَتَمَ ٱللَّهُ" contains Allah
        let v2 = service.verse(surahId: 2, ayahId: 7)!
        let jRules2 = v2.annotations.filter { $0.rule == .lamJalalah }
        #expect(!jRules2.isEmpty, "2:7 should have Lam al-Jalalah annotation")
    }

    @Test func idhaarNoonSakinahAnnotated() async {
        let service = await loadedService()
        // 2:4 "وَبِٱلْـَٔاخِرَةِ" — but let's find a clear noon sakinah + throat letter
        // 1:7 "أَنْعَمْتَ" — noon sakinah followed by ع (ain, a throat letter) = idhaar
        let verse = service.verse(surahId: 1, ayahId: 7)!
        let zRules = verse.annotations.filter { $0.rule == .idhaar }
        #expect(!zRules.isEmpty, "1:7 should have Idhaar annotation (أَنْعَمْتَ)")
    }

    @Test func idhaarTanweenAnnotated() async {
        let service = await loadedService()
        // 2:7 has عَذَابٌ عَظِيمٌ — dammatan on ب followed by ع (throat letter) = idhaar
        let verse = service.verse(surahId: 2, ayahId: 7)!
        let zRules = verse.annotations.filter { $0.rule == .idhaar }
        #expect(!zRules.isEmpty, "2:7 should have Idhaar annotation (tanween before throat letter)")
    }

    @Test func cleanArabicTextPreservesAllMarks() {
        // No characters should be stripped — cascade font handles rendering
        let allMarks = "\u{06D6}\u{06D7}\u{06DA}\u{06DD}\u{06DE}\u{06E9}\u{06EA}\u{06ED}"
        let cleaned = TajweedService.cleanArabicText(allMarks)
        #expect(cleaned.unicodeScalars.count == allMarks.unicodeScalars.count,
                "No characters should be removed")
    }

    @Test func raTafkheemAnnotated() async {
        let service = await loadedService()
        // 1:1 "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ" — Ra + shadda + fatha = tafkheem
        let verse = service.verse(surahId: 1, ayahId: 1)!
        let rRules = verse.annotations.filter { $0.rule == .raTafkheem }
        #expect(!rRules.isEmpty, "1:1 should have Ra Tafkheem annotation")
    }

    @Test func raTarqeeqAnnotated() async {
        let service = await loadedService()
        // 2:26 contains "رِزْقًا" — Ra + kasra = tarqeeq
        let verse = service.verse(surahId: 2, ayahId: 25)!
        let eRules = verse.annotations.filter { $0.rule == .raTarqeeq }
        #expect(!eRules.isEmpty, "2:25 should have Ra Tarqeeq annotation")
    }

    @Test func raSakinAfterKasraWithIstila() async {
        let service = await loadedService()
        // 78:21 "مِرْصَادًا" — Ra sakin after kasra, followed by ص (isti'la) = tafkheem
        let verse = service.verse(surahId: 78, ayahId: 21)!
        let rRules = verse.annotations.filter { $0.rule == .raTafkheem }
        #expect(!rRules.isEmpty, "78:21 should have Ra Tafkheem (isti'la exception)")
    }

    @Test func supplementalTajweedRulesMatchExpectedSet() {
        let supplementalRules = Set(TajweedRule.allCases.filter(\.isSupplemental))
        #expect(supplementalRules == Set([
            .hamzatWasl,
            .lamShamsiyyah,
            .maddNormal,
            .maddPermissible,
            .maddObligatory,
            .maddNecessary,
        ]))
    }

    @Test func supplementalRulesHideByDefaultAndAppearWhenEnabled() {
        for rule in TajweedRule.allCases {
            let visibleByDefault = rule.isVisible(showSupplementalRules: false)
            let visibleWithSupplementals = rule.isVisible(showSupplementalRules: true)

            if rule.isSupplemental {
                #expect(!visibleByDefault, "\(rule) should be hidden by default")
            } else {
                #expect(visibleByDefault, "\(rule) should be visible by default")
            }

            #expect(visibleWithSupplementals, "\(rule) should be visible when supplemental rules are enabled")
        }
    }

    @Test func cleanArabicTextSubstitutesEquivalents() {
        // Test each substitution independently to avoid grapheme cluster issues
        let r1 = TajweedService.cleanArabicText("ا\u{06DF}")
        #expect(r1.unicodeScalars.contains { $0.value == 0x06E0 })
        #expect(!r1.unicodeScalars.contains { $0.value == 0x06DF })

        let r2 = TajweedService.cleanArabicText("\u{0672}")
        #expect(r2.unicodeScalars.contains { $0.value == 0x0670 })
        #expect(!r2.unicodeScalars.contains { $0.value == 0x0672 })

        let r3 = TajweedService.cleanArabicText("\u{066E}")
        #expect(r3.unicodeScalars.contains { $0.value == 0x0649 })
        #expect(!r3.unicodeScalars.contains { $0.value == 0x066E })
    }
}
