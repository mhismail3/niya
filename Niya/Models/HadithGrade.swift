import SwiftUI

enum HadithGrade: String, Sendable {
    case sahih
    case hasan
    case daif
    case mawdu

    var displayName: String {
        switch self {
        case .sahih: "Sahih"
        case .hasan: "Hasan"
        case .daif: "Da'if"
        case .mawdu: "Mawdu'"
        }
    }

    var color: Color {
        switch self {
        case .sahih: .niyaTeal
        case .hasan: .niyaGold
        case .daif: .niyaSecondary
        case .mawdu: .red.opacity(0.7)
        }
    }

    static func from(_ string: String?) -> HadithGrade? {
        guard let s = string?.lowercased() else { return nil }
        if s.contains("mawdu") || s.contains("maudu") || s.contains("fabricat")
            || s.contains("repudiated") {
            return .mawdu
        }
        if s.contains("sahih") || s.contains("qawi") || s.contains("jayyid")
            || s.contains("agreed upon") || s.contains("muttafaq")
            || s.contains("sound") || s.contains("strong") {
            return .sahih
        }
        if s.contains("hasan") || s.contains("good") || s.contains("fair") {
            return .hasan
        }
        if s.contains("daif") || s.contains("da'if") || s.contains("da'of")
            || s.contains("da'eef") || s.contains("d'eef") || s.contains("dai'f")
            || s.contains("da 'eef") || s.contains("weak") || s.contains("munqati") {
            return .daif
        }
        return nil
    }
}
