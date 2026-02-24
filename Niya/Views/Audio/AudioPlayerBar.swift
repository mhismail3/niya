import SwiftUI

struct AudioPlayerBar: View {
    @Environment(AudioPlayerViewModel.self) private var vm
    @Environment(QuranDataService.self) private var dataService

    var body: some View {
        if vm.isPlaying || vm.isLoading {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentTitle)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Color.niyaText)
                        .lineLimit(1)
                    Text(currentSubtitle)
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                }

                Spacer()

                if vm.isLoading {
                    ProgressView()
                        .tint(Color.niyaGold)
                } else {
                    Button(action: vm.togglePause) {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                            .foregroundStyle(Color.niyaGold)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: vm.stop) {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundStyle(Color.niyaSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect()
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.subheadline)
                    .foregroundStyle(Color.niyaSecondary.opacity(0.45))
                Text("Tap a verse to play")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var currentTitle: String {
        if let vid = vm.currentVerseID {
            let name = dataService.surahs.first(where: { $0.id == vid.surahId })?.transliteration ?? ""
            return "\(name) · Verse \(vid.ayahId)"
        } else if let sid = vm.currentSurahId {
            return dataService.surahs.first(where: { $0.id == sid })?.transliteration ?? "Playing"
        }
        return "Playing"
    }

    private var currentSubtitle: String {
        if let vid = vm.currentVerseID {
            return dataService.surahs.first(where: { $0.id == vid.surahId })?.name ?? ""
        }
        return "Mishary Rashid Al-Afasy"
    }
}
