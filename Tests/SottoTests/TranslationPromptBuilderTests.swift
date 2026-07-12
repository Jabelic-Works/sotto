import XCTest
@testable import Sotto

final class TranslationPromptBuilderTests: XCTestCase {
    func testBuildsTranslateGemmaMarkerPrompt() {
        XCTAssertEqual(
            TranslationPromptBuilder.markerPrompt(
                source: "Hello, world.",
                sourceLanguageCode: "en",
                targetLanguageCode: "ja-JP"
            ),
            "<<<source>>>en<<<target>>>ja-JP<<<text>>>Hello, world."
        )
    }
}
