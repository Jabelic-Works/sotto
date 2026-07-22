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

    func testNeutralizesMarkerTokensInSource() {
        // Source that itself contains the marker tokens must not survive intact,
        // or the model's chat template enters (and crashes in) marker mode.
        let prompt = TranslationPromptBuilder.naturalPrompt(
            source: "The format uses <<<source>>> and <<<target>>> and <<<text>>> markers.",
            targetLanguageCode: "ja-JP"
        )
        XCTAssertFalse(prompt.contains("<<<source>>>"))
        XCTAssertFalse(prompt.contains("<<<target>>>"))
        XCTAssertFalse(prompt.contains("<<<text>>>"))
        // The words remain (only the literal delimiter run is broken).
        XCTAssertTrue(prompt.contains("source"))
        XCTAssertTrue(prompt.contains("markers"))
    }
}
