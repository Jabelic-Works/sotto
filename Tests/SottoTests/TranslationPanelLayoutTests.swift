import XCTest
@testable import Sotto

final class TranslationPanelLayoutTests: XCTestCase {
    private let bounds = TranslationPanelLayout.Bounds(maxWidth: 620, maxHeight: 560)

    func testGrowsWithContentWithinBounds() {
        let size = TranslationPanelLayout.clamp(width: 480, height: 300, in: bounds)
        XCTAssertEqual(size.width, 480)
        XCTAssertEqual(size.height, 300)
    }

    func testClampsToMinimum() {
        let size = TranslationPanelLayout.clamp(width: 100, height: 40, in: bounds)
        XCTAssertEqual(size.width, TranslationPanelLayout.minSize.width)
        XCTAssertEqual(size.height, TranslationPanelLayout.minSize.height)
    }

    func testClampsToMaximum() {
        let size = TranslationPanelLayout.clamp(width: 5000, height: 5000, in: bounds)
        XCTAssertEqual(size.width, 620)
        XCTAssertEqual(size.height, 560)
    }

    func testHandlesBoundsSmallerThanMinimum() {
        let tightBounds = TranslationPanelLayout.Bounds(maxWidth: 200, maxHeight: 80)
        let size = TranslationPanelLayout.clamp(width: 400, height: 400, in: tightBounds)
        // Minimum wins so the panel never collapses below a usable size.
        XCTAssertEqual(size.width, TranslationPanelLayout.minSize.width)
        XCTAssertEqual(size.height, TranslationPanelLayout.minSize.height)
    }
}
