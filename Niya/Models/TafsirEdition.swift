import Foundation

enum TafsirEdition: String, CaseIterable, Identifiable, Codable {
    case ibnKathir = "ibn_kathir"
    case maarifUlQuran = "maarif_ul_quran"
    case ibnAbbas = "ibn_abbas"
    case tazkirulQuran = "tazkirul_quran"
    case tafheemUlQuran = "tafheem_ul_quran"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ibnKathir: return "Ibn Kathir"
        case .maarifUlQuran: return "Ma'ariful Quran"
        case .ibnAbbas: return "Ibn Abbas"
        case .tazkirulQuran: return "Tazkirul Quran"
        case .tafheemUlQuran: return "Tafheem ul Quran"
        }
    }

    var author: String {
        switch self {
        case .ibnKathir: return "Isma'il ibn Kathir"
        case .maarifUlQuran: return "Mufti Muhammad Shafi"
        case .ibnAbbas: return "Abdullah ibn Abbas"
        case .tazkirulQuran: return "Wahiduddin Khan"
        case .tafheemUlQuran: return "Abul A'la Maududi"
        }
    }

    var subtitle: String {
        switch self {
        case .ibnKathir: return "Classical comprehensive commentary"
        case .maarifUlQuran: return "Hanafi scholarly commentary"
        case .ibnAbbas: return "Companion-era commentary"
        case .tazkirulQuran: return "Modern reflective commentary"
        case .tafheemUlQuran: return "Modern socio-political commentary"
        }
    }

    var bundleFilename: String {
        "tafsir_\(rawValue)"
    }

    var bundleDirectory: String {
        "tafsir_\(rawValue)"
    }
}
