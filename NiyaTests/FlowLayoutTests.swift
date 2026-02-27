import CoreGraphics
import Testing
@testable import Niya

@Suite("FlowLayout")
struct FlowLayoutTests {

    // MARK: - Row computation

    @Test func singleRow_allFit() {
        let rows = FlowLayout.computeRows(itemWidths: [50, 60, 40], containerWidth: 200, spacing: 8)
        #expect(rows == [[0, 1, 2]])
    }

    @Test func multipleRows_wrapsCorrectly() {
        // 50 + 8 + 60 = 118, then 40 doesn't fit in 120 (118 + 8 + 40 = 166)
        let rows = FlowLayout.computeRows(itemWidths: [50, 60, 40], containerWidth: 120, spacing: 8)
        #expect(rows == [[0, 1], [2]])
    }

    @Test func singleItemPerRow() {
        let rows = FlowLayout.computeRows(itemWidths: [100, 100, 100], containerWidth: 100, spacing: 8)
        #expect(rows == [[0], [1], [2]])
    }

    @Test func exactFit() {
        // 50 + 8 + 42 = 100, exactly fills
        let rows = FlowLayout.computeRows(itemWidths: [50, 42], containerWidth: 100, spacing: 8)
        #expect(rows == [[0, 1]])
    }

    @Test func emptyItems() {
        let rows = FlowLayout.computeRows(itemWidths: [], containerWidth: 300, spacing: 8)
        #expect(rows == [[]])
    }

    @Test func spacingAccountedInRowBreak() {
        // Without spacing: 50 + 50 = 100 fits. With spacing=10: 50 + 10 + 50 = 110 > 100
        let rows = FlowLayout.computeRows(itemWidths: [50, 50], containerWidth: 100, spacing: 10)
        #expect(rows == [[0], [1]])
    }

    // MARK: - RTL position computation

    @Test func rtlPositions_singleRow() {
        let rows = [[0, 1, 2]]
        let widths: [CGFloat] = [50, 60, 40]
        let positions = FlowLayout.rtlXPositions(itemWidths: widths, rows: rows, containerWidth: 300, spacing: 8)
        // First item at right edge: 300 - 50 = 250
        // Second item: 250 - 8 - 60 = 182
        // Third item: 182 - 8 - 40 = 134
        #expect(positions.count == 3)
        #expect(positions[0] == (index: 0, x: 250))
        #expect(positions[1] == (index: 1, x: 182))
        #expect(positions[2] == (index: 2, x: 134))
    }

    @Test func rtlPositions_multipleRows() {
        let rows = [[0, 1], [2]]
        let widths: [CGFloat] = [50, 60, 40]
        let positions = FlowLayout.rtlXPositions(itemWidths: widths, rows: rows, containerWidth: 300, spacing: 8)
        // Row 0: item 0 at 250, item 1 at 182
        // Row 1: item 2 at 260 (300 - 40)
        #expect(positions.count == 3)
        #expect(positions[0] == (index: 0, x: 250))
        #expect(positions[1] == (index: 1, x: 182))
        #expect(positions[2] == (index: 2, x: 260))
    }

    @Test func rtlPositions_noOverlap() {
        let widths: [CGFloat] = [80, 70, 60, 50, 40]
        let rows = FlowLayout.computeRows(itemWidths: widths, containerWidth: 200, spacing: 8)
        let positions = FlowLayout.rtlXPositions(itemWidths: widths, rows: rows, containerWidth: 200, spacing: 8)
        // Group by row and check no overlaps
        for row in rows {
            let rowPositions = positions.filter { row.contains($0.index) }
            for i in 0..<rowPositions.count {
                let aStart = rowPositions[i].x
                let aEnd = aStart + widths[rowPositions[i].index]
                for j in (i + 1)..<rowPositions.count {
                    let bStart = rowPositions[j].x
                    let bEnd = bStart + widths[rowPositions[j].index]
                    let overlaps = aStart < bEnd && bStart < aEnd
                    #expect(!overlaps, "Items \(rowPositions[i].index) and \(rowPositions[j].index) overlap")
                }
            }
        }
    }

    @Test func rtlPositions_contiguous() {
        let widths: [CGFloat] = [50, 60, 40]
        let rows = [[0, 1, 2]]
        let positions = FlowLayout.rtlXPositions(itemWidths: widths, rows: rows, containerWidth: 300, spacing: 8)
        // Items should be contiguous with spacing between them
        // Sorted by x descending (RTL): item0 at 250, item1 at 182, item2 at 134
        let sorted = positions.sorted { $0.x > $1.x }
        for i in 0..<(sorted.count - 1) {
            let gap = sorted[i].x - (sorted[i + 1].x + widths[sorted[i + 1].index])
            #expect(gap == 8, "Gap between items should equal spacing")
        }
    }

    // MARK: - Edge cases matching real Arabic text scenarios

    @Test func manySmallItems_sevenPerRow() {
        // Simulate 8 words at 40pt each + 8pt spacing in 350pt container
        // Row capacity: 40 + (40+8)*N-1 <= 350 → 7 items (40 + 6*48 = 328), 8th causes wrap
        let widths: [CGFloat] = Array(repeating: 40, count: 8)
        let rows = FlowLayout.computeRows(itemWidths: widths, containerWidth: 350, spacing: 8)
        #expect(rows.count == 2)
        #expect(rows[0].count == 7)
        #expect(rows[1].count == 1)
    }

    @Test func mixedWidths_wideAndNarrow() {
        // Simulate particles (20pt) next to long words (120pt) in 300pt container
        let widths: [CGFloat] = [120, 20, 120, 20, 120]
        let rows = FlowLayout.computeRows(itemWidths: widths, containerWidth: 300, spacing: 8)
        // 120 + 8 + 20 + 8 + 120 = 276 fits; 276 + 8 + 20 = 304 > 300
        #expect(rows[0] == [0, 1, 2])
        #expect(rows[1] == [3, 4])
    }
}
