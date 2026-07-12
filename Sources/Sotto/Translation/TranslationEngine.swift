import Foundation

protocol TranslationEngine: Sendable {
    func translate(_ source: String, targetLanguage: String) async throws -> String
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
        TranslationPromptBuilder.markerPrompt(
            source: source,
            sourceLanguageCode: sourceLanguageCode(for: source),
            targetLanguageCode: targetLanguageCode(for: targetLanguage)
        )
    }

    private func maxTokens(for source: String) -> Int {
        min(max(512, source.count * 2), 2048)
    }

    private func sourceLanguageCode(for source: String) -> String {
        source.containsJapaneseText ? "ja" : "en"
    }

    private func targetLanguageCode(for targetLanguage: String) -> String {
        switch targetLanguage.lowercased() {
        case "japanese", "ja", "ja-jp":
            return "ja-JP"
        case "english", "en", "en-us", "en-gb":
            return "en"
        default:
            return targetLanguage
        }
    }
}

enum TranslationPromptBuilder {
    static func markerPrompt(
        source: String,
        sourceLanguageCode: String,
        targetLanguageCode: String
    ) -> String {
        "<<<source>>>\(sourceLanguageCode)<<<target>>>\(targetLanguageCode)<<<text>>>\(source)"
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
