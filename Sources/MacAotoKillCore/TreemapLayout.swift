import CoreGraphics
import Foundation

/// Squarified treemap（Bruls 等）：按面积把矩形切成接近正方形的块，用于平铺展示各 App 的内存占用。
public enum TreemapLayout {
    /// 返回与 `values` 同序的矩形。`values` 按降序传入时块形最接近正方形；非正值得到空矩形。
    public static func squarified(_ values: [Double], in bounds: CGRect) -> [CGRect] {
        var rects = Array(repeating: CGRect.zero, count: values.count)
        let total = values.reduce(0) { $0 + max($1, 0) }
        guard total > 0, bounds.width > 0, bounds.height > 0 else { return rects }

        let scale = Double(bounds.width * bounds.height) / total
        let items = values.indices
            .filter { values[$0] > 0 }
            .map { (index: $0, area: values[$0] * scale) }

        var remaining = bounds
        var row: [(index: Int, area: Double)] = []
        var position = 0

        while position < items.count {
            let side = Double(min(remaining.width, remaining.height))
            let candidate = row + [items[position]]
            if row.isEmpty || worstAspectRatio(candidate, side: side) <= worstAspectRatio(row, side: side) {
                row = candidate
                position += 1
            } else {
                place(row, in: &remaining, rects: &rects)
                row = []
            }
        }
        place(row, in: &remaining, rects: &rects)
        return rects
    }

    private static func worstAspectRatio(_ row: [(index: Int, area: Double)], side: Double) -> Double {
        let sum = row.reduce(0) { $0 + $1.area }
        guard sum > 0, side > 0 else { return .infinity }
        let largest = row.map(\.area).max() ?? 0
        let smallest = row.map(\.area).min() ?? 0
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * largest / sumSquared, sumSquared / (sideSquared * smallest))
    }

    /// 把一行沿较短边铺开，并从剩余区域里扣掉这一行。
    private static func place(
        _ row: [(index: Int, area: Double)],
        in remaining: inout CGRect,
        rects: inout [CGRect]
    ) {
        let sum = row.reduce(0) { $0 + $1.area }
        guard sum > 0 else { return }

        if remaining.width >= remaining.height {
            let width = CGFloat(sum / Double(remaining.height))
            var y = remaining.minY
            for item in row {
                let height = CGFloat(item.area) / width
                rects[item.index] = CGRect(x: remaining.minX, y: y, width: width, height: height)
                y += height
            }
            remaining = CGRect(
                x: remaining.minX + width,
                y: remaining.minY,
                width: max(0, remaining.width - width),
                height: remaining.height
            )
        } else {
            let height = CGFloat(sum / Double(remaining.width))
            var x = remaining.minX
            for item in row {
                let width = CGFloat(item.area) / height
                rects[item.index] = CGRect(x: x, y: remaining.minY, width: width, height: height)
                x += width
            }
            remaining = CGRect(
                x: remaining.minX,
                y: remaining.minY + height,
                width: remaining.width,
                height: max(0, remaining.height - height)
            )
        }
    }
}
