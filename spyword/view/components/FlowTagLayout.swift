import SwiftUI

struct FlowTagLayout: Layout {
    var maxRows: Int = 3
    var itemSpacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
    var segmentSpacing: CGFloat = 8
    var rowHeight: CGFloat = 36
    var viewportWidthHint: CGFloat = 320

    // MARK: - Layout
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let viewportWidth = validViewportWidth(from: proposal)
        let result = layout(subviews: subviews, viewportWidth: viewportWidth)
        // Fixed-height strip (maxRows rows)
        let height = CGFloat(maxRows) * rowHeight + CGFloat(maxRows - 1) * rowSpacing
        return CGSize(width: result.totalWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let viewportWidth = bounds.width.isFinite && bounds.width > 0 ? bounds.width : viewportWidthHint
        let result = layout(subviews: subviews, viewportWidth: viewportWidth)

        for (i, frame) in result.frames.enumerated() {
            subviews[i].place(
                at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    // MARK: - Engine
    private func validViewportWidth(from proposal: ProposedViewSize) -> CGFloat {
        let w = proposal.width ?? .nan
        return (w.isFinite && w > 0) ? w : viewportWidthHint
    }

    /// Lay out items in 3 rows, always choosing the row with the smallest X that can fit.
    private func layout(subviews: Subviews, viewportWidth: CGFloat) -> (frames: [CGRect], totalWidth: CGFloat) {
        guard maxRows > 0 else { return ([], 0) }

        var frames: [CGRect] = Array(repeating: .zero, count: subviews.count)

        // Segment start x; each row's current right edge (within the segment)
        var segmentStartX: CGFloat = 0
        var rowX = Array(repeating: CGFloat(0), count: maxRows).map { _ in segmentStartX }
        var segmentMaxRight: CGFloat = segmentStartX

        func startNewSegment() {
            // width used by current segment
            let currentRight = max(segmentMaxRight, rowX.max() ?? segmentStartX)
            let segmentWidth = currentRight - segmentStartX

            // advance to next segment
            segmentStartX += segmentWidth + segmentSpacing
            segmentMaxRight = segmentStartX
            for r in 0..<maxRows { rowX[r] = segmentStartX }
        }

        for (i, sub) in subviews.enumerated() {
            // chip size (height will be forced to rowHeight)
            let ideal = sub.sizeThatFits(.unspecified)
            let w = ideal.width
            let h = rowHeight

            // pick the row with the smallest current X that can fit
            var chosenRow: Int? = nil
            var chosenPlaceX: CGFloat = .greatestFiniteMagnitude

            for r in 0..<maxRows {
                let x = rowX[r]
                let isRowStart = (x == segmentStartX)
                let neededWidth = (isRowStart ? w : (w + itemSpacing))
                let available = viewportWidth - (x - segmentStartX)

                if neededWidth <= available {
                    let placeX = isRowStart ? x : (x + itemSpacing)
                    // Choose the *leftmost* feasible row to keep rows balanced
                    if placeX < chosenPlaceX {
                        chosenPlaceX = placeX
                        chosenRow = r
                    }
                }
            }

            if chosenRow == nil {
                // No row can fit → new segment
                startNewSegment()
                chosenRow = 0
                chosenPlaceX = rowX[0]
            }

            let r = chosenRow!
            let placeY = CGFloat(r) * (rowHeight + rowSpacing)
            frames[i] = CGRect(x: chosenPlaceX, y: placeY, width: w, height: h)

            rowX[r] = chosenPlaceX + w
            segmentMaxRight = max(segmentMaxRight, rowX[r])
        }

        let totalWidth = max(segmentMaxRight, rowX.max() ?? 0)
        return (frames, totalWidth)
    }
}
