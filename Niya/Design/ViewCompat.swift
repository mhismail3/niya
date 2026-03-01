import SwiftUI

extension View {
    @ViewBuilder
    func niyaGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    @ViewBuilder
    func hiddenNavBarBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func hiddenAllToolbarBackgrounds() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
                .toolbarBackgroundVisibility(.hidden, for: .bottomBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func onScrollVisibilityDismiss(_ action: @escaping () -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollVisibilityChange(threshold: 0.0) { visible in
                if !visible { action() }
            }
        } else {
            self
        }
    }
}
