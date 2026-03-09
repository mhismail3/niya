import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("WordMorphology")
struct WordMorphologyTests {

    // MARK: - WordMorphology Decoding

    @Test func decodeWithAllFields() throws {
        let json = """
        {"pos":"V","root":"عبد","lemma":"عَبَدَ","features":{"cas":"NOM","mood":"IND","gen":"M","num":"S","per":"1","voice":"ACT","aspect":"PERF","form":"1"}}
        """
        let m = try JSONDecoder().decode(WordMorphology.self, from: Data(json.utf8))
        #expect(m.pos == "V")
        #expect(m.root == "عبد")
        #expect(m.lemma == "عَبَدَ")
        #expect(m.features?.cas == "NOM")
        #expect(m.features?.mood == "IND")
        #expect(m.features?.gen == "M")
        #expect(m.features?.num == "S")
        #expect(m.features?.per == "1")
        #expect(m.features?.voice == "ACT")
        #expect(m.features?.aspect == "PERF")
        #expect(m.features?.form == "1")
    }

    @Test func decodeWithNilRoot() throws {
        let json = """
        {"pos":"P"}
        """
        let m = try JSONDecoder().decode(WordMorphology.self, from: Data(json.utf8))
        #expect(m.pos == "P")
        #expect(m.root == nil)
        #expect(m.lemma == nil)
        #expect(m.features == nil)
    }

    @Test func decodeWithNilLemma() throws {
        let json = """
        {"pos":"N","root":"رحم"}
        """
        let m = try JSONDecoder().decode(WordMorphology.self, from: Data(json.utf8))
        #expect(m.root == "رحم")
        #expect(m.lemma == nil)
    }

    // MARK: - MorphFeatures Decoding

    @Test func decodeFeaturesAllFields() throws {
        let json = """
        {"cas":"GEN","mood":"SUBJ","gen":"F","num":"D","per":"2","voice":"PASS","aspect":"IMPF","form":"4"}
        """
        let f = try JSONDecoder().decode(MorphFeatures.self, from: Data(json.utf8))
        #expect(f.cas == "GEN")
        #expect(f.mood == "SUBJ")
        #expect(f.gen == "F")
        #expect(f.num == "D")
        #expect(f.per == "2")
        #expect(f.voice == "PASS")
        #expect(f.aspect == "IMPF")
        #expect(f.form == "4")
    }

    @Test func decodeFeaturesAllNil() throws {
        let json = "{}"
        let f = try JSONDecoder().decode(MorphFeatures.self, from: Data(json.utf8))
        #expect(f.cas == nil)
        #expect(f.mood == nil)
        #expect(f.gen == nil)
        #expect(f.num == nil)
        #expect(f.per == nil)
        #expect(f.voice == nil)
        #expect(f.aspect == nil)
        #expect(f.form == nil)
    }

    @Test func decodeFeaturesPartial() throws {
        let json = """
        {"cas":"NOM","gen":"M"}
        """
        let f = try JSONDecoder().decode(MorphFeatures.self, from: Data(json.utf8))
        #expect(f.cas == "NOM")
        #expect(f.gen == "M")
        #expect(f.mood == nil)
        #expect(f.num == nil)
    }

    // MARK: - RootEntry Decoding

    @Test func decodeRootEntryWithRefs() throws {
        let json = """
        {"freq":3,"refs":[{"s":1,"v":1,"p":3},{"s":1,"v":3,"p":1},{"s":1,"v":3,"p":2}]}
        """
        let r = try JSONDecoder().decode(RootEntry.self, from: Data(json.utf8))
        #expect(r.freq == 3)
        #expect(r.refs.count == 3)
        #expect(r.refs[0].s == 1)
        #expect(r.refs[0].v == 1)
        #expect(r.refs[0].p == 3)
        #expect(r.meaning == nil)
    }

    @Test func decodeRootEntryEmptyRefs() throws {
        let json = """
        {"freq":0,"refs":[]}
        """
        let r = try JSONDecoder().decode(RootEntry.self, from: Data(json.utf8))
        #expect(r.freq == 0)
        #expect(r.refs.isEmpty)
    }

    // MARK: - MorphologyData Top-Level

    @Test func decodeMorphologyData() throws {
        let json = """
        {"words":{"1:1:1":{"pos":"N","root":"سمو","lemma":"اسم","features":{"gen":"M","cas":"GEN"}}},"roots":{"سمو":{"freq":1,"refs":[{"s":1,"v":1,"p":1}]}}}
        """
        let d = try JSONDecoder().decode(MorphologyData.self, from: Data(json.utf8))
        #expect(d.words.count == 1)
        #expect(d.roots.count == 1)
        #expect(d.words["1:1:1"]?.root == "سمو")
        #expect(d.roots["سمو"]?.freq == 1)
    }

    // MARK: - MorphRef

    @Test func decodeMorphRef() throws {
        let json = """
        {"s":2,"v":255,"p":1}
        """
        let r = try JSONDecoder().decode(MorphRef.self, from: Data(json.utf8))
        #expect(r.s == 2)
        #expect(r.v == 255)
        #expect(r.p == 1)
    }

    @Test func morphRefEquality() {
        let a = MorphRef(s: 1, v: 1, p: 1)
        let b = MorphRef(s: 1, v: 1, p: 1)
        let c = MorphRef(s: 1, v: 1, p: 2)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - WordMorphology Hashable

    @Test func wordMorphologyHashable() {
        let a = WordMorphology(root: "رحم", lemma: "رحيم", pos: "ADJ", features: MorphFeatures(cas: "GEN", gen: "M"))
        let b = WordMorphology(root: "رحم", lemma: "رحيم", pos: "ADJ", features: MorphFeatures(cas: "GEN", gen: "M"))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    // MARK: - MorphLabel POS

    @Test func posLabelsKnownTags() {
        let cases: [(String, String, String)] = [
            ("N", "Noun", "اسم"),
            ("PN", "Proper Noun", "اسم علم"),
            ("ADJ", "Adjective", "صفة"),
            ("V", "Verb", "فعل"),
            ("P", "Preposition", "حرف جر"),
            ("CONJ", "Conjunction", "حرف عطف"),
            ("DET", "Determiner", "أداة تعريف"),
            ("REL", "Relative Pronoun", "اسم موصول"),
            ("DEM", "Demonstrative", "اسم إشارة"),
            ("PRON", "Pronoun", "ضمير"),
            ("NEG", "Negation", "حرف نفي"),
            ("INTG", "Interrogative", "اسم استفهام"),
            ("COND", "Conditional", "أداة شرط"),
            ("VOC", "Vocative", "حرف نداء"),
            ("EMPH", "Emphatic", "حرف توكيد"),
            ("T", "Time Adverb", "ظرف زمان"),
            ("LOC", "Location", "ظرف مكان"),
        ]
        for (tag, en, ar) in cases {
            let label = MorphLabel.pos(tag)
            #expect(label != nil, "POS tag '\(tag)' should have a label")
            #expect(label?.en == en, "POS tag '\(tag)' en should be '\(en)'")
            #expect(label?.ar == ar, "POS tag '\(tag)' ar should be '\(ar)'")
        }
    }

    @Test func posLabelUnknownTag() {
        #expect(MorphLabel.pos("UNKNOWN") == nil)
    }

    // MARK: - MorphLabel Case

    @Test func caseLabels() {
        #expect(MorphLabel.cas("NOM")?.en == "Nominative")
        #expect(MorphLabel.cas("NOM")?.ar == "مرفوع")
        #expect(MorphLabel.cas("ACC")?.en == "Accusative")
        #expect(MorphLabel.cas("GEN")?.en == "Genitive")
    }

    @Test func caseLabelUnknown() {
        #expect(MorphLabel.cas("X") == nil)
    }

    // MARK: - MorphLabel Mood

    @Test func moodLabels() {
        #expect(MorphLabel.mood("IND")?.en == "Indicative")
        #expect(MorphLabel.mood("SUBJ")?.en == "Subjunctive")
        #expect(MorphLabel.mood("JUS")?.en == "Jussive")
    }

    // MARK: - MorphLabel Gender

    @Test func genderLabels() {
        #expect(MorphLabel.gender("M")?.en == "Masculine")
        #expect(MorphLabel.gender("M")?.ar == "مذكر")
        #expect(MorphLabel.gender("F")?.en == "Feminine")
        #expect(MorphLabel.gender("F")?.ar == "مؤنث")
    }

    // MARK: - MorphLabel Number

    @Test func numberLabels() {
        #expect(MorphLabel.number("S")?.en == "Singular")
        #expect(MorphLabel.number("D")?.en == "Dual")
        #expect(MorphLabel.number("P")?.en == "Plural")
    }

    // MARK: - MorphLabel Person

    @Test func personLabels() {
        #expect(MorphLabel.person("1")?.en == "First")
        #expect(MorphLabel.person("1")?.ar == "متكلم")
        #expect(MorphLabel.person("2")?.en == "Second")
        #expect(MorphLabel.person("3")?.en == "Third")
    }

    // MARK: - MorphLabel Voice

    @Test func voiceLabels() {
        #expect(MorphLabel.voice("ACT")?.en == "Active")
        #expect(MorphLabel.voice("ACT")?.ar == "معلوم")
        #expect(MorphLabel.voice("PASS")?.en == "Passive")
    }

    // MARK: - MorphLabel Aspect

    @Test func aspectLabels() {
        #expect(MorphLabel.aspect("PERF")?.en == "Perfect")
        #expect(MorphLabel.aspect("IMPF")?.en == "Imperfect")
        #expect(MorphLabel.aspect("IMPV")?.en == "Imperative")
        #expect(MorphLabel.aspect("IMPV")?.ar == "أمر")
    }

    // MARK: - MorphLabel Verb Form

    @Test func verbFormLabels() {
        let expected: [(String, String, String)] = [
            ("1", "Form I", "فَعَلَ"),
            ("2", "Form II", "فَعَّلَ"),
            ("3", "Form III", "فاعَلَ"),
            ("4", "Form IV", "أَفْعَلَ"),
            ("5", "Form V", "تَفَعَّلَ"),
            ("6", "Form VI", "تَفاعَلَ"),
            ("7", "Form VII", "انْفَعَلَ"),
            ("8", "Form VIII", "افْتَعَلَ"),
            ("9", "Form IX", "افْعَلَّ"),
            ("10", "Form X", "اسْتَفْعَلَ"),
        ]
        for (tag, en, ar) in expected {
            let label = MorphLabel.verbForm(tag)
            #expect(label?.en == en)
            #expect(label?.ar == ar)
        }
    }

    @Test func verbFormUnknown() {
        #expect(MorphLabel.verbForm("99") == nil)
    }

    // MARK: - RootEntry freq matches refs

    @Test func rootEntryFreqMatchesRefs() {
        let refs = [MorphRef(s: 1, v: 1, p: 3), MorphRef(s: 1, v: 3, p: 1)]
        let entry = RootEntry(freq: 2, refs: refs)
        #expect(entry.freq == entry.refs.count)
    }
}
