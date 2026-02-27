import SwiftUI

struct AudioPlayerBar: View {
    @Environment(AudioPlayerViewModel.self) private var vm
    @Environment(QuranDataService.self) private var dataService
    @AppStorage("selectedReciter") private var selectedReciter: Reciter = .alAfasy

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentTitle)
                    .font(.niyaSubheadline)
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
                Button {
                    vm.togglePause()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Color.niyaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
            }

            Button {
                vm.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .foregroundStyle(Color.niyaSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .glassEffect()
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
        return selectedReciter.displayName
    }
}
