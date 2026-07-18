import XCTest
@testable import Sotto

final class TranslationRouteTests: XCTestCase {
    func testEnglishSourceTranslatesToJapanese() {
        let route = TranslationRoute.resolve(source: "Hello, world.", preferredTarget: "Japanese")
        XCTAssertEqual(route.sourceCode, "en")
        XCTAssertEqual(route.targetCode, "ja-JP")
    }

    func testJapaneseSourceFlipsToEnglishWhenTargetIsAlsoJapanese() {
        // Selecting Japanese text while the preferred target is Japanese must not
        // produce a same-language paraphrase; it should translate to English.
        let route = TranslationRoute.resolve(source: "こんにちは、世界。", preferredTarget: "Japanese")
        XCTAssertEqual(route.sourceCode, "ja")
        XCTAssertEqual(route.targetCode, "en")
    }

    func testEnglishSourceFlipsToJapaneseWhenTargetIsAlsoEnglish() {
        let route = TranslationRoute.resolve(source: "Hello.", preferredTarget: "English")
        XCTAssertEqual(route.sourceCode, "en")
        XCTAssertEqual(route.targetCode, "ja-JP")
    }

    func testJapaneseSourceKeepsExplicitEnglishTarget() {
        let route = TranslationRoute.resolve(source: "返品したいです。", preferredTarget: "English")
        XCTAssertEqual(route.sourceCode, "ja")
        XCTAssertEqual(route.targetCode, "en")
    }

    func testKanaOnlyTextIsDetectedAsJapanese() {
        let route = TranslationRoute.resolve(source: "ありがとう", preferredTarget: "Japanese")
        XCTAssertEqual(route.sourceCode, "ja")
        XCTAssertEqual(route.targetCode, "en")
    }

    func testNormalizesTargetLanguageAliases() {
        XCTAssertEqual(TranslationRoute.targetCode(for: "ja"), "ja-JP")
        XCTAssertEqual(TranslationRoute.targetCode(for: "JAPANESE"), "ja-JP")
        XCTAssertEqual(TranslationRoute.targetCode(for: "en-US"), "en")
    }
}
