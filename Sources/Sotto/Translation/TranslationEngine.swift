import Foundation

protocol TranslationEngine: Sendable {
    func translate(_ source: String, targetLanguage: String) async throws -> String
}

struct EchoTranslationEngine: TranslationEngine {
    func translate(_ source: String, targetLanguage: String) async throws -> String {
        source
    }
}

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
                maxTokens: 512
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
            guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty
            else {
                throw TranslationError.emptyResponse
            }

            return content
        } catch let error as TranslationError {
            throw error
        } catch is DecodingError {
            throw TranslationError.invalidResponse
        } catch {
            throw TranslationError.connectionFailed(error.localizedDescription)
        }
    }

    private func prompt(source: String, targetLanguage: String) -> String {
        """
        Translate the following text into \(targetLanguage).
        Return only the translated text.

        \(source)
        """
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
