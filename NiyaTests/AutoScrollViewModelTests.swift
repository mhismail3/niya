import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("AutoScrollViewModel")
struct AutoScrollViewModelTests {

    @Test func initialState() {
        let vm = AutoScrollViewModel()
        #expect(vm.isEnabled == false)
        #expect(vm.isScrolling == false)
        #expect(vm.wordsPerMinute == 30)
    }

    @Test func toggleScrolling_togglesState() {
        let vm = AutoScrollViewModel()
        vm.toggleScrolling()
        #expect(vm.isScrolling == true)
        vm.toggleScrolling()
        #expect(vm.isScrolling == false)
    }

    @Test func incrementSpeed_clampsAtMax() {
        let vm = AutoScrollViewModel()
        vm.wordsPerMinute = 75
        vm.incrementSpeed()
        #expect(vm.wordsPerMinute == 80)
        vm.incrementSpeed()
        #expect(vm.wordsPerMinute == 80)
    }

    @Test func decrementSpeed_clampsAtMin() {
        let vm = AutoScrollViewModel()
        vm.wordsPerMinute = 15
        vm.decrementSpeed()
        #expect(vm.wordsPerMinute == 10)
        vm.decrementSpeed()
        #expect(vm.wordsPerMinute == 10)
    }

    @Test func stop_clearsBothFlags() {
        let vm = AutoScrollViewModel()
        vm.isEnabled = true
        vm.isScrolling = true
        vm.stop()
        #expect(vm.isEnabled == false)
        #expect(vm.isScrolling == false)
    }

    @Test func pointsPerSecond_calculation() {
        let vm = AutoScrollViewModel()
        vm.wordsPerMinute = 30
        #expect(vm.pointsPerSecond == 45.0)
        vm.wordsPerMinute = 60
        #expect(vm.pointsPerSecond == 90.0)
    }
}
