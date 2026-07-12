import XCTest
@testable import Sotto

final class TranslationOutputCleanerTests: XCTestCase {
    func testTrimsWhitespace() {
        XCTAssertEqual(TranslationOutputCleaner.clean("  こんにちは\n"), "こんにちは")
    }

    func testRemovesEnglishLabel() {
        XCTAssertEqual(TranslationOutputCleaner.clean("Translation: こんにちは"), "こんにちは")
    }

    func testRemovesJapaneseLabel() {
        XCTAssertEqual(TranslationOutputCleaner.clean("翻訳: こんにちは"), "こんにちは")
    }

    func testRemovesSurroundingQuotes() {
        XCTAssertEqual(TranslationOutputCleaner.clean("\"こんにちは\""), "こんにちは")
        XCTAssertEqual(TranslationOutputCleaner.clean("「こんにちは」"), "こんにちは")
    }

    func testPreservesInternalQuotes() {
        XCTAssertEqual(TranslationOutputCleaner.clean("彼は「こんにちは」と言った。"), "彼は「こんにちは」と言った。")
    }
}
