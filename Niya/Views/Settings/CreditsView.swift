import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Niya is built on the work of countless scholars, reciters, translators, and open-source contributors. We are grateful to every source listed here.")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                }

                ForEach(Self.sections) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            CreditRow(entry: entry)
                        }
                    } header: {
                        Text(section.title)
                    } footer: {
                        if let footer = section.footer {
                            Text(footer)
                        }
                    }
                }

                Section {
                    VStack(spacing: 4) {
                        Text("If an attribution is missing or incorrect, please let us know via the Report an Issue option.")
                            .multilineTextAlignment(.center)
                    }
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Sources & Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct CreditRow: View {
    let entry: CreditEntry

    var body: some View {
        if let url = entry.url {
            Link(destination: url) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                if entry.url != nil {
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote)
                        .foregroundStyle(Color.niyaSecondary)
                }
            }
            if let detail = entry.detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.niyaSecondary)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct CreditEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String?
    let url: URL?

    init(_ title: String, _ detail: String? = nil, url: String? = nil) {
        self.title = title
        self.detail = detail
        self.url = url.flatMap(URL.init(string:))
    }
}

private struct CreditSection: Identifiable {
    let id = UUID()
    let title: String
    let footer: String?
    let entries: [CreditEntry]

    init(_ title: String, footer: String? = nil, _ entries: [CreditEntry]) {
        self.title = title
        self.footer = footer
        self.entries = entries
    }
}

private extension CreditsView {
    static let sections: [CreditSection] = [
        CreditSection(
            "Arabic Quran Text",
            footer: "Canonical Uthmani text maintained by KFGQPC and the Tanzil Project; the Indo-Pak Nastaleeq edition is distributed by Quran.com.",
            [
                CreditEntry(
                    "Uthmani (Hafs) Mushaf",
                    "King Fahd Glorious Quran Printing Complex, Madinah",
                    url: "https://qurancomplex.gov.sa"
                ),
                CreditEntry(
                    "Tanzil Quran Text",
                    "Tanzil Project — verified Uthmanic corpus",
                    url: "https://tanzil.net"
                ),
                CreditEntry(
                    "Indo-Pak (Nastaleeq) Mushaf",
                    "Distributed via the Quran.com API",
                    url: "https://api.quran.com/api/v4/quran/verses/indopak"
                ),
            ]
        ),

        CreditSection(
            "Translations",
            footer: "Most translations are hosted by the Tanzil Project via AlQuran.cloud. Pashto (Rowwad) and Greek (Rowwad) are hosted by QuranEnc / King Fahd Complex. The bundled selection is curated to reflect Sunni scholarship.",
            [
                CreditEntry("English — Saheeh International", "Saheeh International (Jeddah)"),
                CreditEntry("English — The Clear Quran", "Dr. Mustafa Khattab (Al-Azhar)", url: "https://www.clearquran.com"),
                CreditEntry("English — Al-Hilali & Khan", "Muhammad Taqi-ud-Din al-Hilali and Muhammad Muhsin Khan (KFGQPC)"),
                CreditEntry("French — Hamidullah", "Dr. Muhammad Hamidullah"),
                CreditEntry("Spanish — Isa García", "Isa García (modern 2014 translation)", url: "https://noblequran.co"),
                CreditEntry("Italian — Piccardo", "Hamza Roberto Piccardo (UCOII, 1994)"),
                CreditEntry("Turkish — Diyanet", "Diyanet İşleri Başkanlığı", url: "https://www.diyanet.gov.tr"),
                CreditEntry("Urdu — Maududi", "Syed Abul Aala Maududi"),
                CreditEntry("Pashto — Abdulwali Khan", "Mufti Abdul Wali Khan al-Darwazi"),
                CreditEntry("Pashto — Rowwad", "Rowwad Translation Center / KFGQPC", url: "https://quranenc.com/en/browse/pashto_rwwad"),
                CreditEntry("Persian — Khorramdel", "Mostafa Khorramdel (Tafsir-e Nur, 1994)"),
                CreditEntry("Greek — Rowwad", "Rowwad Translation Center / KFGQPC", url: "https://quranenc.com/en/browse/greek_rwwad"),
                CreditEntry("Indonesian — Kemenag", "Indonesian Ministry of Religious Affairs"),
                CreditEntry("Bengali — Muhiuddin Khan", "Muhiuddin Khan"),
                CreditEntry("German — Bubenheim & Elyas", "A.S.F. Bubenheim and N. Elyas (KFGQPC)"),
                CreditEntry("Russian — Kuliev", "Elmir Kuliev"),
                CreditEntry("Malay — Basmeih", "Abdullah Muhammad Basmeih"),
                CreditEntry("Chinese — Ma Jian", "Muhammad Ma Jian (1939)"),
                CreditEntry("Burmese — Ghazi Hashim", "Ghazi Muhammad Hashim"),
                CreditEntry("Tanzil Project (hosting)", "Canonical translation corpus", url: "https://tanzil.net/trans"),
                CreditEntry("AlQuran.cloud API", "Translation distribution endpoint", url: "https://alquran.cloud/api"),
                CreditEntry("QuranEnc.com", "Rowwad / KFGQPC translations", url: "https://quranenc.com"),
            ]
        ),

        CreditSection(
            "Audio Reciters",
            footer: "Audio is streamed from islamic.network (owned by AlQuran.cloud) and QuranicAudio.com. All reciters are bundled with attribution only — copyrights belong to the reciters.",
            [
                CreditEntry("Mishary Rashid Al-Afasy", "Reciter, Grand Mosque of Kuwait"),
                CreditEntry("Noreen Mohammad Siddiq", "Sudanese reciter"),
                CreditEntry("AbdulBaset AbdulSamad", "Egyptian reciter"),
                CreditEntry("Abdur-Rahman as-Sudais", "Imam, Masjid al-Haram"),
                CreditEntry("Abu Bakr al-Shatri", "Saudi reciter"),
                CreditEntry("Hani ar-Rifai", "Saudi reciter"),
                CreditEntry("Mahmoud Khalil Al-Husary", "Egyptian reciter"),
                CreditEntry("Sa'ud ash-Shuraym", "Imam, Masjid al-Haram"),
                CreditEntry("Salah Bukhatir", "UAE-based reciter"),
                CreditEntry("islamic.network CDN", "Audio distribution", url: "https://islamic.network"),
                CreditEntry("QuranicAudio.com", "Audio distribution", url: "https://quranicaudio.com"),
            ]
        ),

        CreditSection(
            "Tafsir (Exegesis)",
            footer: "Tafsir corpora aggregated by the spa5k/tafsir_api open-source repository from public-domain and author-permitted sources.",
            [
                CreditEntry("Tafsir Ibn Kathir", "Al-Hafiz Ibn Kathir (d. 774 AH)"),
                CreditEntry("Maarif ul-Quran", "Mufti Muhammad Shafi Usmani"),
                CreditEntry("Tanwir al-Miqbas (Tafsir Ibn Abbas)", "Attributed to Ibn Abbas (compiled later)"),
                CreditEntry("Tazkirul Quran", "Mawlana Wahiduddin Khan"),
                CreditEntry("spa5k/tafsir_api", "Aggregation repository", url: "https://github.com/spa5k/tafsir_api"),
            ]
        ),

        CreditSection(
            "Hadith Collections",
            footer: "Hadith text from the AhmedBaset/hadith-json repository; authenticity grades from the fawazahmed0/hadith-api project.",
            [
                CreditEntry("Sahih al-Bukhari", "Imam Muhammad ibn Ismail al-Bukhari (d. 256 AH)"),
                CreditEntry("Sahih Muslim", "Imam Muslim ibn al-Hajjaj (d. 261 AH)"),
                CreditEntry("Sunan Abu Dawud", "Imam Abu Dawud al-Sijistani (d. 275 AH)"),
                CreditEntry("Jami' al-Tirmidhi", "Imam al-Tirmidhi (d. 279 AH)"),
                CreditEntry("Sunan an-Nasa'i", "Imam al-Nasa'i (d. 303 AH)"),
                CreditEntry("Sunan Ibn Majah", "Imam Ibn Majah (d. 273 AH)"),
                CreditEntry("Muwatta Malik", "Imam Malik ibn Anas (d. 179 AH)"),
                CreditEntry("Musnad Ahmad", "Imam Ahmad ibn Hanbal (d. 241 AH)"),
                CreditEntry("Sunan al-Darimi", "Imam al-Darimi (d. 255 AH)"),
                CreditEntry("40 Hadith Nawawi", "Imam Yahya al-Nawawi (d. 676 AH)"),
                CreditEntry("40 Hadith Qudsi", "Classical compilation"),
                CreditEntry("40 Hadith Shah Waliullah", "Shah Waliullah al-Dehlawi (d. 1176 AH)"),
                CreditEntry("Al-Adab al-Mufrad", "Imam al-Bukhari (d. 256 AH)"),
                CreditEntry("Bulugh al-Maram", "Ibn Hajar al-Asqalani (d. 852 AH)"),
                CreditEntry("Mishkat al-Masabih", "Imam al-Khatib al-Tabrizi (d. 741 AH)"),
                CreditEntry("Riyad as-Salihin", "Imam Yahya al-Nawawi (d. 676 AH)"),
                CreditEntry("Shamail Muhammadiyah", "Imam al-Tirmidhi (d. 279 AH)"),
                CreditEntry("AhmedBaset/hadith-json", "Hadith text repository", url: "https://github.com/AhmedBaset/hadith-json"),
                CreditEntry("fawazahmed0/hadith-api", "Authenticity grades", url: "https://github.com/fawazahmed0/hadith-api"),
                CreditEntry("Sunnah.com", "Reference text & supplementary entries", url: "https://sunnah.com"),
            ]
        ),

        CreditSection(
            "Duas & Supplications",
            [
                CreditEntry("Hisn al-Muslim (Fortress of the Muslim)", "Shaykh Saʿid ibn ʿAli ibn Wahf al-Qahtani"),
                CreditEntry("Dua & Dhikr supplement", "Fitrahive community compilation", url: "https://github.com/fitrahive/dua-dhikr"),
                CreditEntry("Quranic Duas", "Drawn from the Qur'an itself"),
            ]
        ),

        CreditSection(
            "Word-by-Word & Morphology",
            footer: "Per-word translations, roots, and grammatical annotations.",
            [
                CreditEntry("Word-by-word data", "Quran.com API v4", url: "https://api.quran.com/api/v4"),
                CreditEntry("Quranic Arabic Corpus", "Morphology and syntactic annotation", url: "https://corpus.quran.com"),
                CreditEntry("mustafa0x/quran-morphology", "Enhanced morphology dataset", url: "https://github.com/mustafa0x/quran-morphology"),
                CreditEntry("islamAndAi/QURAN-NLP", "Root-meanings dictionary", url: "https://github.com/islamAndAi/QURAN-NLP"),
            ]
        ),

        CreditSection(
            "Tajweed Rules",
            [
                CreditEntry("Quran Tajweed Annotations", "cpfair/quran-tajweed (character-level rule map)", url: "https://github.com/cpfair/quran-tajweed"),
                CreditEntry("Tanzil Uthmanic baseline", "Reference text for tajweed mapping", url: "https://tanzil.net"),
            ]
        ),

        CreditSection(
            "Prayer Times",
            footer: "Prayer times are computed by the Aladhan API using the calculation method selected in Settings.",
            [
                CreditEntry("Aladhan Prayer Times API", "Islamic Network — prayer time service", url: "https://aladhan.com/prayer-times-api"),
            ]
        ),

        CreditSection(
            "Fonts",
            [
                CreditEntry(
                    "KFGQPC Uthmanic Script HAFS",
                    "King Fahd Glorious Quran Printing Complex",
                    url: "https://fonts.qurancomplex.gov.sa"
                ),
                CreditEntry(
                    "AlQuran Indo-Pak",
                    "Distributed by Quran.com",
                    url: "https://quran.com"
                ),
                CreditEntry(
                    "Noto Naskh Arabic",
                    "Google Noto Fonts — SIL Open Font License 1.1",
                    url: "https://fonts.google.com/noto/specimen/Noto+Naskh+Arabic"
                ),
            ]
        ),
    ]
}

#Preview {
    CreditsView()
}
