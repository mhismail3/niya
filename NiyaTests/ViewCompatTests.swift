import SwiftUI
import Testing
@testable import Niya

@Suite("View Compatibility")
@MainActor
struct ViewCompatTests {
    @Test func niyaGlassProducesView() {
        let view = Text("test").niyaGlass()
        #expect(type(of: view) != Never.self)
    }

    @Test func hiddenNavBarBackgroundProducesView() {
        let view = Text("test").hiddenNavBarBackground()
        #expect(type(of: view) != Never.self)
    }

    @Test func hiddenAllToolbarBackgroundsProducesView() {
        let view = Text("test").hiddenAllToolbarBackgrounds()
        #expect(type(of: view) != Never.self)
    }
}
