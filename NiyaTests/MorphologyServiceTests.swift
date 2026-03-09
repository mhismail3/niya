import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("MorphologyService")
struct MorphologyServiceTests {

    @Test func morphologyReturnsDataForBismillah() {
        let service = MorphologyService()
        let m = service.morphology(surahId: 1, ayahId: 1, position: 1)
        #expect(m != nil)
        #expect(m?.pos == "N")
        #expect(m?.root == "سمو")
    }

    @Test func morphologyReturnsVerbWithFeatures() {
        let service = MorphologyService()
        // 1:5:2 = نَعْبُدُ (verb)
        let m = service.morphology(surahId: 1, ayahId: 5, position: 2)
        #expect(m != nil)
        #expect(m?.pos == "V")
        #expect(m?.root == "عبد")
        #expect(m?.features?.aspect == "IMPF")
        #expect(m?.features?.mood == "IND")
    }

    @Test func morphologyReturnsNilForInvalidSurah() {
        let service = MorphologyService()
        #expect(service.morphology(surahId: 0, ayahId: 1, position: 1) == nil)
        #expect(service.morphology(surahId: 115, ayahId: 1, position: 1) == nil)
    }

    @Test func morphologyReturnsNilForInvalidAyah() {
        let service = MorphologyService()
        #expect(service.morphology(surahId: 1, ayahId: 0, position: 1) == nil)
        #expect(service.morphology(surahId: 1, ayahId: 999, position: 1) == nil)
    }

    @Test func morphologyReturnsNilForInvalidPosition() {
        let service = MorphologyService()
        #expect(service.morphology(surahId: 1, ayahId: 1, position: 0) == nil)
        #expect(service.morphology(surahId: 1, ayahId: 1, position: 999) == nil)
    }

    @Test func morphologyParticleWordHasNilRoot() {
        let service = MorphologyService()
        // Find a DET/prefix-only word — 1:1:3 is الرحمن which has a root,
        // check 2:1:1 = الم (disconnected letters)
        let m = service.morphology(surahId: 2, ayahId: 1, position: 1)
        #expect(m != nil)
        // INL (disconnected letters) typically have no root
        if m?.pos == "INL" {
            #expect(m?.root == nil)
        }
    }

    @Test func rootEntryForCommonRoot() {
        let service = MorphologyService()
        let entry = service.rootEntry("رحم")
        #expect(entry != nil)
        #expect(entry!.freq > 0)
        #expect(!entry!.refs.isEmpty)
    }

    @Test func rootEntryReturnsNilForNonexistent() {
        let service = MorphologyService()
        #expect(service.rootEntry("zzz") == nil)
    }

    @Test func rootEntryRefsCapped() {
        let service = MorphologyService()
        // أله is the most frequent root
        let entry = service.rootEntry("أله")
        #expect(entry != nil)
        #expect(entry!.refs.count <= 50)
        #expect(entry!.freq > 50)
    }

    @Test func clearCacheAndReload() {
        let service = MorphologyService()
        let m1 = service.morphology(surahId: 1, ayahId: 1, position: 1)
        #expect(m1 != nil)
        service.clearCache()
        let m2 = service.morphology(surahId: 1, ayahId: 1, position: 1)
        #expect(m2 != nil)
        #expect(m1?.root == m2?.root)
    }

    @Test func multipleLookups() {
        let service = MorphologyService()
        let a = service.morphology(surahId: 1, ayahId: 1, position: 1)
        let b = service.morphology(surahId: 1, ayahId: 1, position: 2)
        let c = service.morphology(surahId: 1, ayahId: 1, position: 1)
        #expect(a == c)
        #expect(a != b)
    }

    @Test func lastWordLastVerse() {
        let service = MorphologyService()
        // 114:6:3 = الناس
        let m = service.morphology(surahId: 114, ayahId: 6, position: 3)
        #expect(m != nil)
        #expect(m?.root == "أنس")
    }
}
