import SwiftUI

struct FlowTagLayout: Layout {
    var maxRows: Int = 3
    var itemSpacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
    var segmentSpacing: CGFloat = 8
    var rowHeight: CGFloat = 36

    var viewportWidthHint: CGFloat = 320

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let viewportWidth = validViewportWidth(from: proposal)
        let result = layout(subviews: subviews, viewportWidth: viewportWidth)
        // Yükseklik: sabit 3 satır (maxRows)
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

    private func validViewportWidth(from proposal: ProposedViewSize) -> CGFloat {
        let w = proposal.width ?? .nan
        return (w.isFinite && w > 0) ? w : viewportWidthHint
    }

    /// 3 satırlık bir segment içinde item’i sırayla satırlara yerleştir.
    /// Hiçbir satıra sığmazsa yeni segmente geç (sağa doğru).
    private func layout(subviews: Subviews, viewportWidth: CGFloat) -> (frames: [CGRect], totalWidth: CGFloat) {
        var frames: [CGRect] = Array(repeating: .zero, count: subviews.count)

        // Segment başlangıcı (x), satırların o segment içindeki mevcut x’leri
        var segmentStartX: CGFloat = 0
        var rowX = Array(repeating: CGFloat(0), count: maxRows)
        var segmentMaxRight: CGFloat = 0

        func startNewSegment() {
            // Mevcut segment genişliği:
            let currentSegmentRight = max(segmentMaxRight, rowX.max() ?? segmentStartX)
            let currentSegmentWidth = currentSegmentRight - segmentStartX

            // Yeni segmentin başlangıcı:
            segmentStartX += currentSegmentWidth + segmentSpacing
            segmentMaxRight = segmentStartX
            for r in 0..<maxRows { rowX[r] = segmentStartX }
        }

        for (i, sub) in subviews.enumerated() {
            // Item ideal boyutunu al, yükseklik sabitlenecek
            let ideal = sub.sizeThatFits(.unspecified)
            let w = ideal.width
            let h = rowHeight

            var placed = false

            // Sırasıyla 0..maxRows-1 satırı dene
            for r in 0..<maxRows {
                let x = rowX[r]
                let isRowStart = (x == segmentStartX)
                let neededWidth = (isRowStart ? w : (w + itemSpacing))
                let available = viewportWidth - (x - segmentStartX)

                if neededWidth <= available {
                    // Sığıyor, yerleştir
                    let placeX = isRowStart ? x : (x + itemSpacing)
                    let placeY = CGFloat(r) * (rowHeight + rowSpacing)
                    frames[i] = CGRect(x: placeX, y: placeY, width: w, height: h)

                    rowX[r] = placeX + w
                    segmentMaxRight = max(segmentMaxRight, rowX[r])
                    placed = true
                    break
                }
            }

            if !placed {
                // 3 satırın hiçbirine sığmadı -> YENİ SEGMENTE GEÇ
                startNewSegment()

                // Yeni segmentte ilk satıra koy (garanti sığar, çünkü segment boş)
                let r = 0
                let x = rowX[r]
                let y = CGFloat(r) * (rowHeight + rowSpacing)
                frames[i] = CGRect(x: x, y: y, width: w, height: h)
                rowX[r] = x + w
                segmentMaxRight = max(segmentMaxRight, rowX[r])
            }
        }

        let totalWidth = max(segmentMaxRight, rowX.max() ?? 0)
        return (frames, totalWidth)
    }
}
