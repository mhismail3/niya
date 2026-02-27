import Foundation

struct QuranWord: Codable, Identifiable, Sendable, Hashable {
    let p: Int
    let t: String
    let tr: String
    let en: String
    let a: String
    let s: Int
    let e: Int

    var id: Int { p }

    var audioURL: URL { URL(string: "https://audio.qurancdn.com/\(a)")! }

    var durationMs: Int { e - s }

    var displayText: String {
        t.unicodeScalars.filter { scalar in
            !(0x06D6...0x06ED ~= scalar.value)
        }.map { String($0) }.joined()
    }
}

struct VerseWordData: Codable, Sendable {
    let au: String
    let vs: Int
    let ve: Int
    let w: [QuranWord]
}

enum WordHighlightState: Equatable {
    case current, completed, upcoming
}
