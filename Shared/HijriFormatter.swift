import Foundation

enum HijriFormatter {
    static let monthNames = [
        "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani",
        "Jumada al-Ula", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhul Qi'dah", "Dhul Hijjah"
    ]

    static func format(date: Date, includeYear: Bool = true) -> String {
        let hijriCal = Calendar(identifier: .islamicUmmAlQura)
        let comps = hijriCal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return ""
        }
        let monthName = (month >= 1 && month <= 12) ? monthNames[month - 1] : "Unknown"
        if includeYear {
            return "\(day) \(monthName) \(year) AH"
        }
        return "\(day) \(monthName)"
    }
}
