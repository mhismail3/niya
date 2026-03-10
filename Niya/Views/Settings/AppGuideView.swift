import SwiftUI

struct AppGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Reading the Quran") {
                    guideRow("book", "Scroll & Page Modes", "Switch between continuous scroll and traditional page-by-page reading in Settings.")
                    guideRow("character.book.closed", "Hafs & IndoPak Scripts", "Choose your preferred Arabic script style.")
                    guideRow("globe", "Translations", "Show or hide English translations below each verse.")
                    guideRow("paintpalette", "Tajweed Color-Coding", "Color-coded tajweed rules on Hafs text. Tap a colored word to see the rule name.")
                    guideRow("bookmark", "Bookmarks", "Tap the bookmark icon on any verse to save it. Access bookmarks from the Search tab.")
                }

                Section("Word-by-Word") {
                    guideRow("text.word.spacing", "Follow Along", "Enable word-by-word highlighting that tracks with audio playback.")
                    guideRow("hand.tap", "Tap a Word", "Tap any word to hear its individual pronunciation.")
                    guideRow("hand.tap.fill", "Long-Press a Word", "Long-press to see root letters, morphology, grammar, and related verses.")
                    guideRow("character.textbox", "Transliteration & Meanings", "Toggle per-word transliteration and meanings in multiple languages.")
                }

                Section("Audio") {
                    guideRow("play.circle", "Play Surah or Verse", "Play the full surah or tap a verse number to play a single verse.")
                    guideRow("person.wave.2", "9 Reciters", "Choose from Al-Afasy, Noreen Siddiq, Bukhatir, and 6 more in Settings.")
                    guideRow("arrow.down.circle", "Download Audio", "Download surahs for offline listening from the reader settings.")
                    guideRow("repeat", "Repeat & Speed", "Loop verses and adjust playback speed from 0.5x to 1.25x.")
                }

                Section("Search") {
                    guideRow("magnifyingglass", "3-Scope Search", "Search across Quran verses, Hadith texts, and Duas from one place.")
                }

                Section("Hadith") {
                    guideRow("books.vertical", "7 Collections", "Browse Bukhari, Muslim, Tirmidhi, and the other main hadith books.")
                    guideRow("list.bullet", "Chapters & Grades", "Navigate by chapter. Hadiths show authenticity grades when available.")
                    guideRow("bookmark", "Bookmarking", "Bookmark any hadith for quick access later.")
                }

                Section("Duas") {
                    guideRow("hands.and.sparkles", "Sections & Categories", "Browse 280 duas across 11 thematic sections and 133 categories.")
                    guideRow("bookmark", "Bookmarking", "Save your favorite duas for easy reference.")
                }

                Section("Prayer Times & Qiblah") {
                    guideRow("location.north.circle", "Qiblah Compass", "Live compass pointing toward the Kaaba. Open from the toolbar location icon.")
                    guideRow("clock", "Prayer Times", "Accurate times with 20 calculation methods and Hanafi/Shafi'i asr options.")
                    guideRow("bell", "Notifications", "Get notified before each prayer time.")
                    guideRow("widget.small", "Widgets", "Add prayer time widgets to your home screen and lock screen.")
                }

                Section("Tips & Gestures") {
                    guideRow("hand.tap", "Tap Verse Number", "Tap a verse number to play that specific verse.")
                    guideRow("hand.draw", "Swipe in Page Mode", "Swipe left and right to turn pages in mushaf page mode.")
                    guideRow("text.book.closed", "Tafsir", "Open detailed Quran commentary from the tafsir button in the reader toolbar.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("How to Use This App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func guideRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.niyaTeal)
                .frame(width: 24)
        }
        .padding(.vertical, 4)
    }
}
