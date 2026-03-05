import SwiftUI

enum BookmarkColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case emerald, sapphire, rose, plum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emerald:  "Emerald"
        case .sapphire: "Sapphire"
        case .rose:     "Rose"
        case .plum:     "Plum"
        }
    }

    var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? self.darkUIColor : self.lightUIColor
        })
    }

    private var lightUIColor: UIColor {
        switch self {
        case .emerald:  UIColor(red: 0.13, green: 0.55, blue: 0.42, alpha: 1)
        case .sapphire: UIColor(red: 0.25, green: 0.47, blue: 0.70, alpha: 1)
        case .rose:     UIColor(red: 0.76, green: 0.38, blue: 0.38, alpha: 1)
        case .plum:     UIColor(red: 0.55, green: 0.30, blue: 0.66, alpha: 1)
        }
    }

    private var darkUIColor: UIColor {
        switch self {
        case .emerald:  UIColor(red: 0.30, green: 0.78, blue: 0.62, alpha: 1)
        case .sapphire: UIColor(red: 0.45, green: 0.68, blue: 0.90, alpha: 1)
        case .rose:     UIColor(red: 0.90, green: 0.55, blue: 0.55, alpha: 1)
        case .plum:     UIColor(red: 0.75, green: 0.52, blue: 0.85, alpha: 1)
        }
    }
}
