import Foundation

@Observable
@MainActor
final class AutoScrollViewModel {
    var isEnabled = false
    var isScrolling = false
    var wordsPerMinute: Int = 30

    static let minWPM = 10
    static let maxWPM = 80
    static let wpmStep = 5

    func toggleScrolling() {
        isScrolling.toggle()
    }

    func incrementSpeed() {
        wordsPerMinute = min(wordsPerMinute + Self.wpmStep, Self.maxWPM)
    }

    func decrementSpeed() {
        wordsPerMinute = max(wordsPerMinute - Self.wpmStep, Self.minWPM)
    }

    func stop() {
        isScrolling = false
        isEnabled = false
    }

    /// Pixels per second — controls visual scroll speed.
    var pointsPerSecond: Double {
        Double(wordsPerMinute) * 1.5
    }
}
