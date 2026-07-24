import XCTest
@testable import Sotto

final class AppVersionTests: XCTestCase {
    func testShortVersionWithBuild() {
        XCTAssertEqual(AppVersion.label(shortVersion: "0.3.0", build: "3"), "0.3.0 (3)")
    }

    func testShortVersionWithoutBuild() {
        XCTAssertEqual(AppVersion.label(shortVersion: "0.3.0", build: nil), "0.3.0")
    }

    func testFallsBackToDevWithoutVersion() {
        XCTAssertEqual(AppVersion.label(shortVersion: nil, build: "3"), "dev")
        XCTAssertEqual(AppVersion.label(shortVersion: nil, build: nil), "dev")
    }
}
