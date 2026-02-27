import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rightToLeft: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        if rightToLeft {
            placeRTL(in: bounds, subviews: subviews)
        } else {
            placeLTR(in: bounds, subviews: subviews)
        }
    }

    private func placeLTR(in bounds: CGRect, subviews: Subviews) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + bounds.width && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func placeRTL(in bounds: CGRect, subviews: Subviews) {
        var rows: [[Int]] = [[]]
        var currentRowWidth: CGFloat = 0
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = currentRowWidth > 0 ? size.width + spacing : size.width
            if currentRowWidth + needed > bounds.width && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(i)
            currentRowWidth += currentRowWidth > 0 ? size.width + spacing : size.width
        }
        var y = bounds.minY
        for row in rows {
            var x = bounds.maxX
            var rowHeight: CGFloat = 0
            for i in row {
                let size = subviews[i].sizeThatFits(.unspecified)
                x -= size.width
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x -= spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }
}
