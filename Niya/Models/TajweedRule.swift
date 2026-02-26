import SwiftUI

enum TajweedRule: String, CaseIterable, Codable, Identifiable {
    case hamzatWasl = "h"
    case lamShamsiyyah = "l"
    case maddNormal = "n"
    case maddPermissible = "p"
    case maddObligatory = "o"
    case maddNecessary = "m"
    case ghunnah = "g"
    case qalqalah = "q"
    case silent = "s"
    case ikhfa = "f"
    case idghamGhunnah = "a"
    case idghamNoGhunnah = "u"
    case iqlab = "i"
    case ikhfaShafawi = "c"
    case tafkheem = "d"
    case izharShafawi = "w"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hamzatWasl: "Hamzat al-Wasl"
        case .lamShamsiyyah: "Lam Shamsiyyah"
        case .maddNormal: "Madd (Natural)"
        case .maddPermissible: "Madd Munfasil (Permitted)"
        case .maddObligatory: "Madd Muttasil (Obligatory)"
        case .maddNecessary: "Madd Lazim (Necessary)"
        case .ghunnah: "Ghunnah (Nasalization)"
        case .qalqalah: "Qalqalah (Echo)"
        case .silent: "Silent Letter"
        case .ikhfa: "Ikhfa (Concealment)"
        case .idghamGhunnah: "Idgham with Ghunnah"
        case .idghamNoGhunnah: "Idgham without Ghunnah"
        case .iqlab: "Iqlab (Conversion)"
        case .ikhfaShafawi: "Ikhfa Shafawi"
        case .tafkheem: "Tafkheem (Heavy)"
        case .izharShafawi: "Izhar Shafawi"
        }
    }

    var arabicName: String {
        switch self {
        case .hamzatWasl: "هَمزة الوَصل"
        case .lamShamsiyyah: "لام شَمسِيَّة"
        case .maddNormal: "مَدّ طَبيعي"
        case .maddPermissible: "مَدّ مُنفَصِل"
        case .maddObligatory: "مَدّ مُتَّصِل"
        case .maddNecessary: "مَدّ لازِم"
        case .ghunnah: "غُنَّة"
        case .qalqalah: "قَلقَلة"
        case .silent: "حرف ساكن"
        case .ikhfa: "إخفاء"
        case .idghamGhunnah: "إدغام بغُنَّة"
        case .idghamNoGhunnah: "إدغام بلا غُنَّة"
        case .iqlab: "إقلاب"
        case .ikhfaShafawi: "إخفاء شَفَوي"
        case .tafkheem: "تَفخيم"
        case .izharShafawi: "إظهار شَفَوي"
        }
    }

    var color: Color {
        switch self {
        case .hamzatWasl: Color(.hamzatWasl)
        case .lamShamsiyyah: Color(.lamShamsiyyah)
        case .maddNormal: Color(.maddNormal)
        case .maddPermissible: Color(.maddPermissible)
        case .maddObligatory: Color(.maddObligatory)
        case .maddNecessary: Color(.maddNecessary)
        case .ghunnah: Color(.ghunnah)
        case .qalqalah: Color(.qalqalah)
        case .silent: Color(.silentLetter)
        case .ikhfa: Color(.ikhfa)
        case .idghamGhunnah: Color(.idghamGhunnah)
        case .idghamNoGhunnah: Color(.idghamNoGhunnah)
        case .iqlab: Color(.iqlab)
        case .ikhfaShafawi: Color(.ikhfaShafawi)
        case .tafkheem: Color(.tafkheem)
        case .izharShafawi: Color(.izharShafawi)
        }
    }
}

extension UIColor {
    static let hamzatWasl = UIColor(light: 0x78909C, dark: 0xB0BEC5)
    static let lamShamsiyyah = UIColor(light: 0x795548, dark: 0xBCAAA4)
    static let maddNormal = UIColor(light: 0xC62828, dark: 0xEF5350)
    static let maddPermissible = UIColor(light: 0xC2185B, dark: 0xF06292)
    static let maddObligatory = UIColor(light: 0xB71C1C, dark: 0xE57373)
    static let maddNecessary = UIColor(light: 0x880E4F, dark: 0xF48FB1)
    static let ghunnah = UIColor(light: 0x2E7D32, dark: 0x66BB6A)
    static let qalqalah = UIColor(light: 0x1565C0, dark: 0x64B5F6)
    static let silentLetter = UIColor(light: 0x90A4AE, dark: 0xCFD8DC)
    static let ikhfa = UIColor(light: 0xE65100, dark: 0xFF8A65)
    static let idghamGhunnah = UIColor(light: 0x00796B, dark: 0x4DB6AC)
    static let idghamNoGhunnah = UIColor(light: 0x00838F, dark: 0x4DD0E1)
    static let iqlab = UIColor(light: 0x6A1B9A, dark: 0xBA68C8)
    static let ikhfaShafawi = UIColor(light: 0xBF360C, dark: 0xFF7043)
    static let tafkheem = UIColor(light: 0x4A6572, dark: 0x8EACBB)
    static let izharShafawi = UIColor(light: 0x2E8B57, dark: 0x66CDAA)

    convenience init(light: Int, dark: Int) {
        self.init { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: dark)
                : UIColor(rgb: light)
        }
    }

    private convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
