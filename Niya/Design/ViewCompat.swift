import SwiftUI

extension View {
    /// Sets the policy for descendant scroll views within this presentation.
    @ViewBuilder
    func softScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }

    /// Each sheet has its own presentation root; set the policy inside it.
    func niyaSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content().softScrollEdges()
        }
    }

    func niyaSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            content(item).softScrollEdges()
        }
    }

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
