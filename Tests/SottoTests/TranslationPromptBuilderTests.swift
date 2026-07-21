import XCTest
@testable import Sotto

final class TranslationPromptBuilderTests: XCTestCase {
    func testJapaneseTargetUsesNaturalJapaneseInstruction() {
        let prompt = TranslationPromptBuilder.naturalPrompt(
            source: "Hello, world.",
            targetLanguageCode: "ja-JP"
        )
        XCTAssertTrue(prompt.contains("逐語訳を避け"), "should instruct against literal translation")
        XCTAssertTrue(prompt.contains("自然で読みやすい"), "should ask for natural Japanese")
        XCTAssertTrue(prompt.hasSuffix("Hello, world."), "source text should be appended")
    }

    func testEnglishTargetUsesNaturalEnglishInstruction() {
        let prompt = TranslationPromptBuilder.naturalPrompt(
            source: "こんにちは、世界。",
            targetLanguageCode: "en"
        )
        XCTAssertTrue(prompt.contains("natural"), "should ask for natural English")
        XCTAssertTrue(prompt.contains("Avoid word-for-word"), "should instruct against literal translation")
        XCTAssertTrue(prompt.hasSuffix("こんにちは、世界。"), "source text should be appended")
    }

    func testDoesNotUseMarkerFormat() {
        let prompt = TranslationPromptBuilder.naturalPrompt(source: "Hi", targetLanguageCode: "ja-JP")
        XCTAssertFalse(prompt.contains("<<<source>>>"), "must not fall back to the literal marker format")
    }
}
