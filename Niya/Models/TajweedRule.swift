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
    case idghamMutajanisayn = "d"
    case idghamShafawi = "w"
    case idghamMutaqaribayn = "b"
    case lamJalalah = "j"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hamzatWasl: "Hamzat al-Wasl"
        case .lamShamsiyyah: "Lam Shamsiyyah"
        case .maddNormal: "Madd (Natural)"
        case .maddPermissible: "Permissible Prolongation"
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
        case .idghamMutajanisayn: "Idgham Mutajanisayn"
        case .idghamShafawi: "Idgham Shafawi"
        case .idghamMutaqaribayn: "Idgham Mutaqaribayn"
        case .lamJalalah: "Lam al-Jalalah"
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
        case .idghamMutajanisayn: "إدغام متجانسين"
        case .idghamShafawi: "إدغام شفوي"
        case .idghamMutaqaribayn: "إدغام متقاربين"
        case .lamJalalah: "لام الجَلالة"
        }
    }

    var description: String {
        switch self {
        case .hamzatWasl:
            "A connecting hamza at the start of a word that is pronounced when beginning from that word, but silent when continuing from the previous word without pause."
        case .lamShamsiyyah:
            "The Lam of the definite article (ال) is silent and the following letter is doubled when it precedes one of the 14 sun letters (ت ث د ذ ر ز س ش ص ض ط ظ ل ن)."
        case .maddNormal:
            "A natural prolongation of two counts that occurs when an alif follows a fatha, a waw follows a damma, or a ya follows a kasra with no hamza or sukun after it."
        case .maddPermissible:
            "A prolongation of 4–5 counts that occurs when a madd letter is followed by a hamza in the next word, allowing the reader a range of extension."
        case .maddObligatory:
            "A prolongation of 4–5 counts that is obligatory when a madd letter is followed by a hamza within the same word."
        case .maddNecessary:
            "A prolongation of 6 counts that occurs when a madd letter is followed by a sukun or shaddah in the same word."
        case .ghunnah:
            "A nasalized sound held for two counts, produced through the nasal passage when pronouncing a doubled (mushaddad) nun or mim."
        case .qalqalah:
            "An echoing bounce produced when one of the five qalqalah letters (ق ط ب ج د) carries a sukun, created by slightly separating the articulation point."
        case .silent:
            "A letter that is written in the mushaf but not pronounced during recitation, such as certain instances of alif, waw, or ya."
        case .ikhfa:
            "A concealed pronunciation of noon sakinah or tanween when followed by one of 15 ikhfa letters, producing a sound between izhar and idgham with ghunnah held for two counts."
        case .idghamGhunnah:
            "Noon sakinah or tanween merges into the following letter with a nasalized ghunnah of two counts when followed by ya, nun, mim, or waw (يَنْمُو)."
        case .idghamNoGhunnah:
            "Noon sakinah or tanween merges completely into the following letter without any nasal sound when followed by lam or ra."
        case .iqlab:
            "Noon sakinah or tanween is converted into a mim sound with ghunnah when followed by the letter ba (ب), while maintaining lip closure."
        case .ikhfaShafawi:
            "Mim sakinah is concealed with a light ghunnah of two counts when followed by the letter ba (ب), produced with a slight lip closure."
        case .idghamMutajanisayn:
            "A letter merges into the following letter when both share the same articulation point but differ in characteristics, such as ta into dal or tha into dhal."
        case .idghamShafawi:
            "Mim sakinah merges fully into a following mim with ghunnah of two counts, as both letters share the lip articulation point."
        case .idghamMutaqaribayn:
            "A letter merges into the following letter when their articulation points are close to each other, such as lam into ra or qaf into kaf."
        case .lamJalalah:
            "The Lam in the name of Allah (الله) is pronounced heavy (tafkheem) when preceded by a fatha or damma, and light (tarqeeq) when preceded by a kasra."
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
        case .idghamMutajanisayn: Color(.idghamMutajanisayn)
        case .idghamShafawi: Color(.idghamShafawi)
        case .idghamMutaqaribayn: Color(.idghamMutaqaribayn)
        case .lamJalalah: Color(.lamJalalah)
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
    static let idghamMutajanisayn = UIColor(light: 0x4A6572, dark: 0x8EACBB)
    static let idghamShafawi = UIColor(light: 0x2E8B57, dark: 0x66CDAA)
    static let idghamMutaqaribayn = UIColor(light: 0x4A6572, dark: 0x8EACBB)
    static let lamJalalah = UIColor(light: 0xF9A825, dark: 0xFFD54F)

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
