import Foundation

enum Reciter: String, CaseIterable, Identifiable, Codable {
    case alAfasy
    case noreenSiddiq
    case abdulBaset
    case sudais
    case shatri
    case haniRifai
    case husary
    case shuraym

    var id: String { rawValue }

    private struct Config: Sendable {
        let displayName: String
        let shortName: String
        let hasPerVerseAudio: Bool
        let wordDataFilename: String
        let surahStreamURL: @Sendable (Int) -> URL
        let verseStreamURL: (@Sendable (Int) -> URL?)?
        let localFilenamePrefix: String
    }

    private var config: Config { Self.configs[self]! }

    private static let configs: [Reciter: Config] = {
        func islamicNetworkReciter(
            displayName: String,
            shortName: String,
            networkId: String,
            bitrate: Int,
            surahPath: String,
            surahZeroPad: Bool,
            filenameSlug: String
        ) -> Config {
            Config(
                displayName: displayName,
                shortName: shortName,
                hasPerVerseAudio: true,
                wordDataFilename: "word_data_\(filenameSlug)",
                surahStreamURL: { surahId in
                    let sid = surahZeroPad ? String(format: "%03d", surahId) : "\(surahId)"
                    return URL(string: "https://download.quranicaudio.com/qdc/\(surahPath)/\(sid).mp3")!
                },
                verseStreamURL: { absoluteVerseNumber in
                    URL(string: "https://cdn.islamic.network/quran/audio/\(bitrate)/\(networkId)/\(absoluteVerseNumber).mp3")!
                },
                localFilenamePrefix: "audio_\(filenameSlug)_surah_"
            )
        }

        return [
            .alAfasy: Config(
                displayName: "Mishary Rashid Al-Afasy",
                shortName: "Al-Afasy",
                hasPerVerseAudio: true,
                wordDataFilename: "word_data",
                surahStreamURL: { surahId in
                    URL(string: "https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/\(surahId).mp3")!
                },
                verseStreamURL: { absoluteVerseNumber in
                    URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(absoluteVerseNumber).mp3")!
                },
                localFilenamePrefix: "audio_alafasy_surah_"
            ),
            .noreenSiddiq: Config(
                displayName: "Noreen Mohammad Siddiq",
                shortName: "Noreen Siddiq",
                hasPerVerseAudio: false,
                wordDataFilename: "noreen_word_data",
                surahStreamURL: { surahId in
                    URL(string: "https://download.quranicaudio.com/quran/noreen_siddiq/\(String(format: "%03d", surahId)).mp3")!
                },
                verseStreamURL: nil,
                localFilenamePrefix: "audio_noreen_surah_"
            ),
            .abdulBaset: islamicNetworkReciter(
                displayName: "AbdulBaset AbdulSamad",
                shortName: "AbdulBaset",
                networkId: "ar.abdulsamad",
                bitrate: 64,
                surahPath: "abdul_baset/murattal",
                surahZeroPad: false,
                filenameSlug: "abdulbaset"
            ),
            .sudais: islamicNetworkReciter(
                displayName: "Abdur-Rahman as-Sudais",
                shortName: "As-Sudais",
                networkId: "ar.abdurrahmaansudais",
                bitrate: 64,
                surahPath: "abdurrahmaan_as_sudais/murattal",
                surahZeroPad: false,
                filenameSlug: "sudais"
            ),
            .shatri: islamicNetworkReciter(
                displayName: "Abu Bakr al-Shatri",
                shortName: "Al-Shatri",
                networkId: "ar.shaatree",
                bitrate: 128,
                surahPath: "abu_bakr_shatri/murattal",
                surahZeroPad: false,
                filenameSlug: "shatri"
            ),
            .haniRifai: islamicNetworkReciter(
                displayName: "Hani ar-Rifai",
                shortName: "Ar-Rifai",
                networkId: "ar.hanirifai",
                bitrate: 64,
                surahPath: "hani_ar_rifai/murattal",
                surahZeroPad: false,
                filenameSlug: "hanirifai"
            ),
            .husary: islamicNetworkReciter(
                displayName: "Mahmoud Khalil Al-Husary",
                shortName: "Al-Husary",
                networkId: "ar.husary",
                bitrate: 128,
                surahPath: "khalil_al_husary/murattal",
                surahZeroPad: false,
                filenameSlug: "husary"
            ),
            .shuraym: islamicNetworkReciter(
                displayName: "Sa'ud ash-Shuraym",
                shortName: "Ash-Shuraym",
                networkId: "ar.saoodshuraym",
                bitrate: 64,
                surahPath: "saud_ash-shuraym/murattal",
                surahZeroPad: true,
                filenameSlug: "shuraym"
            ),
        ]
    }()

    var displayName: String { config.displayName }

    var shortName: String { config.shortName }

    var hasPerVerseAudio: Bool { config.hasPerVerseAudio }

    var wordDataFilename: String { config.wordDataFilename }

    func surahStreamURL(surahId: Int) -> URL {
        config.surahStreamURL(surahId)
    }

    func verseStreamURL(absoluteVerseNumber: Int) -> URL? {
        config.verseStreamURL?(absoluteVerseNumber)
    }

    func localFilename(for surahId: Int) -> String {
        "\(config.localFilenamePrefix)\(surahId).mp3"
    }
}
