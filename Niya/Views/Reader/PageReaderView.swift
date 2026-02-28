import SwiftUI

struct PageReaderView: View {
    @Bindable var vm: ReaderViewModel
    @State private var scrolledPage: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(vm.pages.enumerated()), id: \.offset) { idx, pageVerses in
                    MushaPageView(
                        verses: pageVerses,
                        script: vm.script,
                        showTranslation: vm.showTranslation,
                        surahId: vm.surah.id,
                        surahName: vm.surah.transliteration,
                        showBismillah: vm.showBismillah
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(idx)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledPage)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            scrolledPage = vm.currentPage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                vm.isSettled = true
            }
        }
        .onDisappear {
            vm.isSettled = false
        }
        .onChange(of: scrolledPage) { _, newPage in
            guard let newPage, newPage >= 0, newPage < vm.pages.count,
                  let firstVerse = vm.pages[newPage].first else { return }
            vm.currentPage = newPage
            vm.updateVisibleAyah(firstVerse.id)
        }
    }
}
