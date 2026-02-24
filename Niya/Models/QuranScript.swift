import Foundation

enum QuranScript: String, CaseIterable, Identifiable, Codable {
    case hafs
    case indoPak

    var id: String { rawValue }

    var fontName: String {
        switch self {
        case .hafs: return "KFGQPCUthmanicScriptHAFS"
        case .indoPak: return "ScheherazadeNew-Regular"
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .hafs: return 28
        case .indoPak: return 26
        }
    }

    var displayName: String {
        switch self {
        case .hafs: return "Uthmanic Hafs"
        case .indoPak: return "IndoPak"
        }
    }
}
