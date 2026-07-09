import XCTest
@testable import Sotto

final class DoubleCopyDetectorTests: XCTestCase {
    func testDetectsSameTextCopiedTwiceWithinInterval() {
        var detector = DoubleCopyDetector(maximumInterval: 0.8)
        let start = Date()

        XCTAssertFalse(detector.record(text: "Hello", at: start))
        XCTAssertTrue(detector.record(text: "Hello", at: start.addingTimeInterval(0.4)))
    }

    func testRejectsDifferentText() {
        var detector = DoubleCopyDetector(maximumInterval: 0.8)
        let start = Date()

        XCTAssertFalse(detector.record(text: "Hello", at: start))
        XCTAssertFalse(detector.record(text: "Bonjour", at: start.addingTimeInterval(0.4)))
    }

    func testRejectsCopiesOutsideInterval() {
        var detector = DoubleCopyDetector(maximumInterval: 0.8)
        let start = Date()

        XCTAssertFalse(detector.record(text: "Hello", at: start))
        XCTAssertFalse(detector.record(text: "Hello", at: start.addingTimeInterval(1)))
    }

    func testConsumesSuccessfulDoubleCopy() {
        var detector = DoubleCopyDetector(maximumInterval: 0.8)
        let start = Date()

        XCTAssertFalse(detector.record(text: "Hello", at: start))
        XCTAssertTrue(detector.record(text: "Hello", at: start.addingTimeInterval(0.2)))
        XCTAssertFalse(detector.record(text: "Hello", at: start.addingTimeInterval(0.3)))
    }
}
