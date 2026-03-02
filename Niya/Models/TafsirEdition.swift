import Foundation

enum TafsirEdition: String, CaseIterable, Identifiable, Codable {
    case ibnKathir = "en-tafisr-ibn-kathir"
    case maarifUlQuran = "en-tafsir-maarif-ul-quran"
    case ibnAbbas = "en-tafsir-ibn-abbas"
    case tazkirulQuran = "en-tazkirul-quran"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ibnKathir: return "Ibn Kathir"
        case .maarifUlQuran: return "Ma'ariful Quran"
        case .ibnAbbas: return "Ibn Abbas"
        case .tazkirulQuran: return "Tazkirul Quran"
        }
    }

    var author: String {
        switch self {
        case .ibnKathir: return "Isma'il ibn Kathir"
        case .maarifUlQuran: return "Mufti Muhammad Shafi"
        case .ibnAbbas: return "Abdullah ibn Abbas"
        case .tazkirulQuran: return "Wahiduddin Khan"
        }
    }

    var subtitle: String {
        switch self {
        case .ibnKathir: return "Classical comprehensive commentary"
        case .maarifUlQuran: return "Hanafi scholarly commentary"
        case .ibnAbbas: return "Companion-era commentary"
        case .tazkirulQuran: return "Modern reflective commentary"
        }
    }

    func url(surahId: Int, ayahId: Int) -> URL? {
        URL(string: "https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/\(rawValue)/\(surahId)/\(ayahId).json")
    }
}

struct TafsirEntry: Decodable {
    let surah: Int
    let ayah: Int
    let text: String
}
