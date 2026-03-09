import Foundation

struct MorphologyData: Codable, Sendable {
    let words: [String: WordMorphology]
    let roots: [String: RootEntry]
}

struct WordMorphology: Codable, Sendable, Hashable {
    let root: String?
    let lemma: String?
    let pos: String
    let features: MorphFeatures?
}

struct MorphFeatures: Codable, Sendable, Hashable {
    let cas: String?
    let mood: String?
    let gen: String?
    let num: String?
    let per: String?
    let voice: String?
    let aspect: String?
    let form: String?

    init(cas: String? = nil, mood: String? = nil, gen: String? = nil,
         num: String? = nil, per: String? = nil, voice: String? = nil,
         aspect: String? = nil, form: String? = nil) {
        self.cas = cas
        self.mood = mood
        self.gen = gen
        self.num = num
        self.per = per
        self.voice = voice
        self.aspect = aspect
        self.form = form
    }
}

struct RootEntry: Codable, Sendable {
    let freq: Int
    let refs: [MorphRef]
    let meaning: String?

    init(freq: Int, refs: [MorphRef], meaning: String? = nil) {
        self.freq = freq
        self.refs = refs
        self.meaning = meaning
    }
}

struct MorphRef: Codable, Sendable, Hashable {
    let s: Int
    let v: Int
    let p: Int
}

struct RootMeaning: Codable, Sendable {
    let pos: String
    let def: String
}

enum MorphLabel {
    static func pos(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "N": ("Noun", "اسم")
        case "PN": ("Proper Noun", "اسم علم")
        case "ADJ": ("Adjective", "صفة")
        case "V": ("Verb", "فعل")
        case "P": ("Preposition", "حرف جر")
        case "CONJ": ("Conjunction", "حرف عطف")
        case "DET": ("Determiner", "أداة تعريف")
        case "REL": ("Relative Pronoun", "اسم موصول")
        case "DEM": ("Demonstrative", "اسم إشارة")
        case "PRON": ("Pronoun", "ضمير")
        case "NEG": ("Negation", "حرف نفي")
        case "INTG": ("Interrogative", "اسم استفهام")
        case "COND": ("Conditional", "أداة شرط")
        case "RES": ("Restriction", "أداة حصر")
        case "CERT": ("Certainty", "حرف تحقيق")
        case "EXP": ("Explanation", "حرف تفسير")
        case "SUP": ("Supplementary", "حرف زائد")
        case "PREV": ("Preventive", "حرف كاف")
        case "ANS": ("Answer", "حرف جواب")
        case "AVR": ("Aversion", "حرف ردع")
        case "INC": ("Inceptive", "حرف ابتداء")
        case "SUR": ("Surprise", "حرف مفاجأة")
        case "VOC": ("Vocative", "حرف نداء")
        case "INL": ("Disconnected Letters", "حروف مقطعة")
        case "EMPH": ("Emphatic", "حرف توكيد")
        case "T": ("Time Adverb", "ظرف زمان")
        case "LOC": ("Location", "ظرف مكان")
        case "ACC": ("Accusative Particle", "حرف نصب")
        default: nil
        }
    }

    static func cas(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "NOM": ("Nominative", "مرفوع")
        case "ACC": ("Accusative", "منصوب")
        case "GEN": ("Genitive", "مجرور")
        default: nil
        }
    }

    static func mood(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "IND": ("Indicative", "مرفوع")
        case "SUBJ": ("Subjunctive", "منصوب")
        case "JUS": ("Jussive", "مجزوم")
        default: nil
        }
    }

    static func gender(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "M": ("Masculine", "مذكر")
        case "F": ("Feminine", "مؤنث")
        default: nil
        }
    }

    static func number(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "S": ("Singular", "مفرد")
        case "D": ("Dual", "مثنى")
        case "P": ("Plural", "جمع")
        default: nil
        }
    }

    static func person(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "1": ("First", "متكلم")
        case "2": ("Second", "مخاطب")
        case "3": ("Third", "غائب")
        default: nil
        }
    }

    static func voice(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "ACT": ("Active", "معلوم")
        case "PASS": ("Passive", "مجهول")
        default: nil
        }
    }

    static func aspect(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "PERF": ("Perfect", "ماضي")
        case "IMPF": ("Imperfect", "مضارع")
        case "IMPV": ("Imperative", "أمر")
        default: nil
        }
    }

    static func verbForm(_ tag: String) -> (en: String, ar: String)? {
        switch tag {
        case "1": ("Form I", "فَعَلَ")
        case "2": ("Form II", "فَعَّلَ")
        case "3": ("Form III", "فاعَلَ")
        case "4": ("Form IV", "أَفْعَلَ")
        case "5": ("Form V", "تَفَعَّلَ")
        case "6": ("Form VI", "تَفاعَلَ")
        case "7": ("Form VII", "انْفَعَلَ")
        case "8": ("Form VIII", "افْتَعَلَ")
        case "9": ("Form IX", "افْعَلَّ")
        case "10": ("Form X", "اسْتَفْعَلَ")
        default: nil
        }
    }
}
