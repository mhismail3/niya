import Foundation

struct QuranWord: Codable, Identifiable, Sendable, Hashable {
    let p: Int
    let t: String
    let tr: String
    let en: String
    let a: String
    let s: Int
    let e: Int
    var meaning: String?

    var id: Int { p }
    var displayMeaning: String { meaning ?? en }

    var audioURL: URL? { URL(string: "https://audio.qurancdn.com/\(a)") }

    var durationMs: Int { e - s }

    private enum CodingKeys: String, CodingKey {
        case p, t, tr, en, a, s, e
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
