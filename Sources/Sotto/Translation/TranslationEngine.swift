import Foundation

protocol TranslationEngine: Sendable {
    func prepare() async throws
    func translate(_ source: String, targetLanguage: String) async throws -> String
}

extension TranslationEngine {
    func prepare() async throws {}
}

struct EchoTranslationEngine: TranslationEngine {
    func translate(_ source: String, targetLanguage: String) async throws -> String {
        source
    }
}

/// Development fallback while Sotto moves toward in-process MLX Swift inference.
struct LocalServerTranslationEngine: TranslationEngine {
    private let endpoint: URL
    private let model: String

    init(
        endpoint: URL = URL(string: "http://127.0.0.1:8000/v1/chat/completions")!,
        model: String = "mlx-community/translategemma-4b-it-4bit_immersive-translate"
    ) {
        self.endpoint = endpoint
        self.model = model
    }

    func translate(_ source: String, targetLanguage: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: model,
                messages: [
                    ChatMessage(
                        role: "user",
                        content: prompt(source: source, targetLanguage: targetLanguage)
                    ),
                ],
                temperature: 0,
                maxTokens: maxTokens(for: source)
            )
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TranslationError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let content = decoded.choices.first?.message.content ?? ""
            let cleanedContent = TranslationOutputCleaner.clean(content)
            guard !cleanedContent.isEmpty
            else {
                throw TranslationError.emptyResponse
            }

            return cleanedContent
        } catch let error as TranslationError {
            throw error
        } catch is DecodingError {
            throw TranslationError.invalidResponse
        } catch {
            throw TranslationError.connectionFailed(error.localizedDescription)
        }
    }

    private func prompt(source: String, targetLanguage: String) -> String {
        let route = TranslationRoute.resolve(source: source, preferredTarget: targetLanguage)
        return TranslationPromptBuilder.naturalPrompt(
            source: source,
            targetLanguageCode: route.targetCode
        )
    }

    private func maxTokens(for source: String) -> Int {
        min(max(512, source.count * 2), 4096)
    }
}

enum TranslationPromptBuilder {
    /// Builds a natural-translation instruction rather than TranslateGemma's
    /// terse `<<<source>>>…` marker format. The marker format triggers a fixed
    /// "professional translator" instruction that tends to translate literally;
    /// an explicit "translate naturally, not word-for-word" instruction produces
    /// noticeably more idiomatic output. The model reads this through its chat
    /// template's plain-text path (no markers).
    ///
    /// Instructions are kept short on purpose: elaborate style guidance makes
    /// this 4-bit model unreliable (it starts emitting stray tokens), so the
    /// wording only nudges toward natural, non-literal phrasing.
    static func naturalPrompt(
        source: String,
        targetLanguageCode: String
    ) -> String {
        let instruction: String
        if targetLanguageCode.hasPrefix("ja") {
            instruction = "プロの翻訳者として、次の文章を日本語に翻訳してください。"
                + "逐語訳を避け、日本語として自然で読みやすい表現にしてください。"
                + "原文の意味は保ち、訳文だけを出力してください。"
        } else if targetLanguageCode.hasPrefix("en") {
            instruction = "As a professional translator, translate the following text into natural, "
                + "fluent English. Avoid word-for-word translation, preserve the original meaning, "
                + "and output only the translation."
        } else {
            instruction = "Translate the following text into \(targetLanguageCode) naturally and "
                + "fluently. Avoid word-for-word translation and output only the translation."
        }
        return "\(instruction)\n\n\(source)"
    }
}

/// Resolves the source/target language codes for a translation.
///
/// The double-copy trigger has no explicit direction, so Sotto infers it from
/// the selected text. The caller supplies a preferred target language (the
/// reader's own language); when the selection already appears to be in that
/// language, the direction is flipped so the model performs a real translation
/// instead of paraphrasing the text back into the same language.
enum TranslationRoute {
    static func resolve(
        source: String,
        preferredTarget: String
    ) -> (sourceCode: String, targetCode: String) {
        let sourceCode = source.containsJapaneseText ? "ja" : "en"
        let preferredCode = targetCode(for: preferredTarget)

        // Avoid same-language "translation" (e.g. selecting Japanese while the
        // preferred target is also Japanese): flip to the other language.
        if sourceCode == "ja", preferredCode.hasPrefix("ja") {
            return ("ja", "en")
        }
        if sourceCode == "en", preferredCode == "en" {
            return ("en", "ja-JP")
        }
        return (sourceCode, preferredCode)
    }

    static func targetCode(for language: String) -> String {
        switch language.lowercased() {
        case "japanese", "ja", "ja-jp", "ja_jp":
            return "ja-JP"
        case "english", "en", "en-us", "en-gb":
            return "en"
        default:
            return language
        }
    }
}

enum TranslationOutputCleaner {
    static func clean(_ content: String) -> String {
        var result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Translation:",
            "Translated text:",
            "Japanese:",
            "日本語訳:",
            "翻訳:",
            "訳:",
        ]

        for prefix in prefixes where result.hasLocalizedCaseInsensitivePrefix(prefix) {
            result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        if result.count >= 2,
           let first = result.first,
           let last = result.last,
           (first == "\"" && last == "\"") || (first == "“" && last == "”") || (first == "「" && last == "」")
        {
            result = String(result.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}

extension String {
    var containsJapaneseText: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x9FFF:
                return true
            default:
                return false
            }
        }
    }

    func hasLocalizedCaseInsensitivePrefix(_ prefix: String) -> Bool {
        guard count >= prefix.count else { return false }
        let candidate = String(self.prefix(prefix.count))
        return candidate.localizedCaseInsensitiveCompare(prefix) == .orderedSame
    }
}

enum TranslationError: LocalizedError {
    case connectionFailed(String)
    case invalidResponse
    case serverError(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .connectionFailed(message):
            return "Local translation server unavailable: \(message)"
        case .invalidResponse:
            return "Local translation server returned an invalid response"
        case let .serverError(statusCode):
            return "Local translation server returned HTTP \(statusCode)"
        case .emptyResponse:
            return "Local translation server returned an empty translation"
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
