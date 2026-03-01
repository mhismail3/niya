import Foundation

enum CalculationMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case mwl
    case isna
    case egypt
    case makkah
    case karachi
    case tehran
    case jafari
    case gulf
    case kuwait
    case qatar
    case singapore
    case france
    case turkey
    case russia
    case moonsighting
    case dubai
    case jakim
    case tunisia
    case algeria
    case indonesia

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mwl: return "Muslim World League"
        case .isna: return "Islamic Society of North America"
        case .egypt: return "Egyptian General Authority"
        case .makkah: return "Umm Al-Qura, Makkah"
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .tehran: return "Institute of Geophysics, Tehran"
        case .jafari: return "Shia Ithna-Ashari, Leva Institute, Qum"
        case .gulf: return "Gulf Region"
        case .kuwait: return "Kuwait"
        case .qatar: return "Qatar"
        case .singapore: return "Islamic Religious Council of Singapore"
        case .france: return "Union of Islamic Organisations of France"
        case .turkey: return "Diyanet, Turkey"
        case .russia: return "Spiritual Administration of Muslims of Russia"
        case .moonsighting: return "Moonsighting Committee"
        case .dubai: return "Dubai"
        case .jakim: return "JAKIM, Malaysia"
        case .tunisia: return "Ministry of Religious Affairs, Tunisia"
        case .algeria: return "Ministry of Religious Affairs, Algeria"
        case .indonesia: return "Ministry of Religious Affairs, Indonesia"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .mwl: return 18.0
        case .isna: return 15.0
        case .egypt: return 19.5
        case .makkah: return 18.5
        case .karachi: return 18.0
        case .tehran: return 17.7
        case .jafari: return 16.0
        case .gulf: return 19.5
        case .kuwait: return 18.0
        case .qatar: return 18.0
        case .singapore: return 20.0
        case .france: return 12.0
        case .turkey: return 18.0
        case .russia: return 16.0
        case .moonsighting: return 18.0
        case .dubai: return 18.2
        case .jakim: return 20.0
        case .tunisia: return 18.0
        case .algeria: return 18.0
        case .indonesia: return 20.0
        }
    }

    var ishaAngle: Double? {
        switch self {
        case .mwl: return 17.0
        case .isna: return 15.0
        case .egypt: return 17.5
        case .makkah: return nil
        case .karachi: return 18.0
        case .tehran: return 14.0
        case .jafari: return 14.0
        case .gulf: return nil
        case .kuwait: return 17.5
        case .qatar: return nil
        case .singapore: return 18.0
        case .france: return 12.0
        case .turkey: return 17.0
        case .russia: return 15.0
        case .moonsighting: return 18.0
        case .dubai: return 18.2
        case .jakim: return 18.0
        case .tunisia: return 18.0
        case .algeria: return 17.0
        case .indonesia: return 18.0
        }
    }

    var ishaMinutesAfterMaghrib: Double? {
        switch self {
        case .makkah: return 90
        case .gulf: return 90
        case .qatar: return 90
        default: return nil
        }
    }

    var aladhanMethodId: Int? {
        switch self {
        case .mwl: return 3
        case .isna: return 2
        case .egypt: return 5
        case .makkah: return 4
        case .karachi: return 1
        case .tehran: return 7
        case .jafari: return 0
        case .gulf: return 8
        case .kuwait: return 9
        case .qatar: return 10
        case .singapore: return 11
        case .france: return 12
        case .turkey: return 13
        case .russia: return 14
        case .moonsighting: return 15
        default: return nil
        }
    }
}
