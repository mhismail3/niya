import SwiftUI
import Testing
import UIKit
@testable import Niya

@MainActor
@Suite("Soft scroll edges", .serialized)
struct ScrollEdgeEffectTests {
    private struct SheetItem: Identifiable {
        let id = 1
    }

    private var scrollContent: some View {
        NavigationStack {
            ScrollView {
                Text("Scrollable test content")
                    .frame(height: 2_000)
            }
            .navigationTitle("Test sheet")
        }
    }

    @Test func booleanSheetUsesSoftEdges() async throws {
        try await verifyPresentedScrollView(
            Color.clear.niyaSheet(isPresented: .constant(true)) {
                scrollContent
            }
        )
    }

    @Test func itemSheetUsesSoftEdges() async throws {
        try await verifyPresentedScrollView(
            Color.clear.niyaSheet(item: .constant(SheetItem())) { _ in
                scrollContent
            }
        )
    }

    private func verifyPresentedScrollView<Content: View>(_ content: Content) async throws {
        guard #available(iOS 26.0, *) else { return }
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: content)
        window.rootViewController = host
        window.isHidden = false
        defer {
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        // Wait only for this test's presentation/layout, without touching the
        // app's services, real stores, defaults, or existing windows.
        var scrollView: UIScrollView?
        for _ in 0..<60 {
            host.view.layoutIfNeeded()
            if let presented = host.presentedViewController {
                presented.view.layoutIfNeeded()
                scrollView = findScrollView(in: presented.view)
                if let scrollView,
                   scrollView.topEdgeEffect.style == .soft,
                   scrollView.bottomEdgeEffect.style == .soft,
                   scrollView.leftEdgeEffect.style == .soft,
                   scrollView.rightEdgeEffect.style == .soft {
                    break
                }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        let scroll = try #require(scrollView, "Sheet must present a scroll view")
        #expect(scroll.topEdgeEffect.style == .soft)
        #expect(scroll.bottomEdgeEffect.style == .soft)
        #expect(scroll.leftEdgeEffect.style == .soft)
        #expect(scroll.rightEdgeEffect.style == .soft)
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        for child in view.subviews {
            if let scroll = findScrollView(in: child) { return scroll }
        }
        return nil
    }
}
