protocol TranslationEngine: Sendable {
    func translate(_ source: String, targetLanguage: String) async throws -> String
}

struct EchoTranslationEngine: TranslationEngine {
    func translate(_ source: String, targetLanguage: String) async throws -> String {
        source
    }
}
