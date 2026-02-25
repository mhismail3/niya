import SwiftUI

struct PageReaderView: View {
    @Bindable var vm: ReaderViewModel

    var body: some View {
        TabView(selection: $vm.currentPage) {
            ForEach(Array(vm.pages.enumerated()), id: \.offset) { idx, pageVerses in
                MushaPageView(
                    verses: pageVerses,
                    script: vm.script,
                    showTranslation: vm.showTranslation,
                    surahId: vm.surah.id
                )
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.niyaBackground)
        .onChange(of: vm.currentPage) { _, newPage in
            guard newPage >= 0, newPage < vm.pages.count,
                  let firstVerse = vm.pages[newPage].first else { return }
            vm.updateVisibleAyah(firstVerse.id)
        }
    }
}
