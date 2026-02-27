import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rightToLeft: Bool = false

    static func computeRows(
        itemWidths: [CGFloat], containerWidth: CGFloat, spacing: CGFloat
    ) -> [[Int]] {
        guard !itemWidths.isEmpty else { return [[]] }
        var rows: [[Int]] = [[]]
        var currentRowWidth: CGFloat = 0
        for i in itemWidths.indices {
            let needed = currentRowWidth > 0 ? itemWidths[i] + spacing : itemWidths[i]
            if currentRowWidth + needed > containerWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(i)
            currentRowWidth += currentRowWidth > 0 ? itemWidths[i] + spacing : itemWidths[i]
        }
        return rows
    }

    static func rtlXPositions(
        itemWidths: [CGFloat], rows: [[Int]],
        containerWidth: CGFloat, spacing: CGFloat
    ) -> [(index: Int, x: CGFloat)] {
        var result: [(index: Int, x: CGFloat)] = []
        for row in rows {
            var x = containerWidth
            for i in row {
                x -= itemWidths[i]
                result.append((index: i, x: x))
                x -= spacing
            }
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let widths = sizes.map(\.width)
        let rows = Self.computeRows(itemWidths: widths, containerWidth: maxWidth, spacing: spacing)

        var totalHeight: CGFloat = 0
        for (rowIdx, row) in rows.enumerated() {
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            totalHeight += rowHeight
            if rowIdx < rows.count - 1 { totalHeight += spacing }
        }
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let widths = sizes.map(\.width)
        let rows = Self.computeRows(itemWidths: widths, containerWidth: bounds.width, spacing: spacing)

        if rightToLeft {
            var y = bounds.minY
            for row in rows {
                var x = bounds.maxX
                let rowHeight = row.map { sizes[$0].height }.max() ?? 0
                for i in row {
                    x -= sizes[i].width
                    subviews[i].place(
                        at: CGPoint(x: x, y: y),
                        proposal: ProposedViewSize(sizes[i])
                    )
                    x -= spacing
                }
                y += rowHeight + spacing
            }
        } else {
            var y = bounds.minY
            for row in rows {
                var x = bounds.minX
                let rowHeight = row.map { sizes[$0].height }.max() ?? 0
                for i in row {
                    subviews[i].place(
                        at: CGPoint(x: x, y: y),
                        proposal: ProposedViewSize(sizes[i])
                    )
                    x += sizes[i].width + spacing
                }
                y += rowHeight + spacing
            }
        }
    }
}
