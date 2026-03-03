import SwiftUI

struct PageReaderView: View {
    @Bindable var vm: ReaderViewModel
    @State private var scrolledPage: Int?
    @State private var highlightTask: Task<Void, Never>?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(vm.pages.enumerated()), id: \.offset) { idx, pageVerses in
                    MushaPageView(
                        verses: pageVerses,
                        script: vm.script,
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
            highlightTask?.cancel()
            highlightTask = nil
        }
        .onChange(of: vm.goToAyahTarget) { _, target in
            guard let target else { return }
            vm.goToAyahTarget = nil
            withAnimation(.easeInOut(duration: 0.4)) {
                scrolledPage = vm.currentPage
            }
            highlightTask?.cancel()
            highlightTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    vm.clearHighlight()
                }
            }
        }
        .onChange(of: scrolledPage) { _, newPage in
            guard let newPage, newPage >= 0, newPage < vm.pages.count,
                  let firstVerse = vm.pages[newPage].first else { return }
            vm.currentPage = newPage
            vm.updateVisibleAyah(firstVerse.id)
        }
    }
}
