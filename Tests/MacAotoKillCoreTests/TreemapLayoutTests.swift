import CoreGraphics
import XCTest
@testable import MacAotoKillCore

final class TreemapLayoutTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)

    func testAreasAreProportionalToValues() {
        let values: [Double] = [6, 6, 4, 3, 2, 2, 1]
        let rects = TreemapLayout.squarified(values, in: bounds)
        let total = values.reduce(0, +)

        XCTAssertEqual(rects.count, values.count)
        for (value, rect) in zip(values, rects) {
            let expectedArea = Double(bounds.width * bounds.height) * value / total
            XCTAssertEqual(Double(rect.width * rect.height), expectedArea, accuracy: 0.01)
        }
    }

    func testRectsStayInsideBoundsWithoutOverlapping() {
        let values: [Double] = [9, 7, 5, 5, 3, 2, 1, 1, 0.5]
        let rects = TreemapLayout.squarified(values, in: bounds)

        for rect in rects {
            XCTAssertTrue(bounds.insetBy(dx: -0.01, dy: -0.01).contains(rect))
        }
        for i in rects.indices {
            for j in rects.indices where j > i {
                let overlap = rects[i].intersection(rects[j])
                XCTAssertLessThan(overlap.isNull ? 0 : overlap.width * overlap.height, 0.01)
            }
        }
    }

    func testNonPositiveValuesGetEmptyRects() {
        let rects = TreemapLayout.squarified([5, 0, -1, 5], in: bounds)

        XCTAssertEqual(rects[1], .zero)
        XCTAssertEqual(rects[2], .zero)
        XCTAssertEqual(Double(rects[0].width * rects[0].height), 120_000, accuracy: 0.01)
        XCTAssertEqual(Double(rects[3].width * rects[3].height), 120_000, accuracy: 0.01)
    }

    func testEmptyInputOrBoundsProduceEmptyRects() {
        XCTAssertEqual(TreemapLayout.squarified([], in: bounds), [])
        XCTAssertEqual(TreemapLayout.squarified([1, 2], in: .zero), [.zero, .zero])
    }

    func testBlocksStayReasonablySquare() {
        let rects = TreemapLayout.squarified([8, 8, 8, 8], in: CGRect(x: 0, y: 0, width: 400, height: 400))

        for rect in rects {
            XCTAssertEqual(Double(rect.width), 200, accuracy: 0.01)
            XCTAssertEqual(Double(rect.height), 200, accuracy: 0.01)
        }
    }
}
