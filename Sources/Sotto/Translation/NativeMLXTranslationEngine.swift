import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

struct NativeMLXTranslationEngine: TranslationEngine {
    static let defaultModelID = "mlx-community/translategemma-4b-it-4bit_immersive-translate"

    private let modelProvider: NativeMLXModelProvider

    init(modelID: String = Self.defaultModelID) {
        self.modelProvider = NativeMLXModelProvider(modelID: modelID)
    }

    func prepare() async throws {
        _ = try await modelProvider.container()
    }

    func translate(_ source: String, targetLanguage: String) async throws -> String {
        let container = try await modelProvider.container()
        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(
                maxTokens: maxTokens(for: source),
                temperature: 0
            )
        )

        let prompt = TranslationPromptBuilder.markerPrompt(
            source: source,
            sourceLanguageCode: sourceLanguageCode(for: source),
            targetLanguageCode: targetLanguageCode(for: targetLanguage)
        )
        let content = try await session.respond(to: prompt)
        let cleanedContent = TranslationOutputCleaner.clean(content)
        guard !cleanedContent.isEmpty else {
            throw TranslationError.emptyResponse
        }

        return cleanedContent
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

private actor NativeMLXModelProvider {
    private let modelID: String
    private var cachedContainer: ModelContainer?
    private var loadingTask: Task<ModelContainer, Error>?

    init(modelID: String) {
        self.modelID = modelID
    }

    func container() async throws -> ModelContainer {
        if let cachedContainer {
            return cachedContainer
        }

        if let loadingTask {
            return try await loadingTask.value
        }

        let modelID = modelID
        let loadingTask = Task<ModelContainer, Error> {
            try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: ModelConfiguration(id: modelID)
            )
        }
        self.loadingTask = loadingTask

        do {
            let container = try await loadingTask.value
            cachedContainer = container
            self.loadingTask = nil
            return container
        } catch {
            self.loadingTask = nil
            throw error
        }
    }
}
