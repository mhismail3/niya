import Foundation

enum Reciter: String, CaseIterable, Identifiable, Codable {
    case alAfasy
    case noreenSiddiq

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alAfasy: return "Mishary Rashid Al-Afasy"
        case .noreenSiddiq: return "Noreen Mohammad Siddiq"
        }
    }

    var shortName: String {
        switch self {
        case .alAfasy: return "Al-Afasy"
        case .noreenSiddiq: return "Noreen Siddiq"
        }
    }

    var hasPerVerseAudio: Bool {
        switch self {
        case .alAfasy: return true
        case .noreenSiddiq: return false
        }
    }

    var wordDataFilename: String {
        switch self {
        case .alAfasy: return "word_data"
        case .noreenSiddiq: return "noreen_word_data"
        }
    }

    func surahStreamURL(surahId: Int) -> URL {
        switch self {
        case .alAfasy:
            return URL(string: "https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/\(surahId).mp3")!
        case .noreenSiddiq:
            return URL(string: "https://download.quranicaudio.com/quran/noreen_siddiq/\(String(format: "%03d", surahId)).mp3")!
        }
    }

    func verseStreamURL(absoluteVerseNumber: Int) -> URL? {
        switch self {
        case .alAfasy:
            return URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(absoluteVerseNumber).mp3")!
        case .noreenSiddiq:
            return nil
        }
    }

    func localFilename(for surahId: Int) -> String {
        switch self {
        case .alAfasy: return "audio_alafasy_surah_\(surahId).mp3"
        case .noreenSiddiq: return "audio_noreen_surah_\(surahId).mp3"
        }
    }
}
