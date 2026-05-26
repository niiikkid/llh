//
//  OpenAIService.swift
//  llh
//

import CoreGraphics
import Foundation
import ImageIO
import Security

struct OpenAIService: OpenAIServing {
    private let httpClient: OpenAIHTTPClient
    private let modelsService: OpenAIModelsService

    init(session: URLSession = .shared) {
        let httpClient = OpenAIHTTPClient(session: session)
        self.httpClient = httpClient
        self.modelsService = OpenAIModelsService(httpClient: httpClient)
    }

    init(httpClient: OpenAIHTTPClient) {
        self.httpClient = httpClient
        self.modelsService = OpenAIModelsService(httpClient: httpClient)
    }

    func recognizeTextInImage(
        apiKey: String,
        modelID: String,
        image: CGImage
    ) async throws -> String {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }
        guard let imageData = Self.jpegData(from: image),
              !imageData.isEmpty else {
            throw OpenAIServiceError.invalidImageData
        }

        let imageBase64 = imageData.base64EncodedString()
        let requestBody = VisionChatCompletionsRequest(
            model: modelID,
            temperature: 0,
            messages: [
                VisionChatMessage(
                    role: "user",
                    content: [
                        .init(type: "text", text: OpenAIPromptBuilder.recognizeTextInImageUserPrompt()),
                        .init(type: "image_url", imageURL: .init(url: "data:image/jpeg;base64,\(imageBase64)"))
                    ]
                )
            ]
        )

        let data = try await httpClient.post(
            path: "/chat/completions",
            apiKey: apiKey,
            body: requestBody
        )
        let decoded = try httpClient.decode(data, as: VisionChatCompletionsResponse.self)
        let recognizedText = decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !recognizedText.isEmpty else {
            throw OpenAIServiceError.emptyRecognizedText
        }
        return TextFormatter.normalizeRecognizedLines(
            recognizedText.components(separatedBy: .newlines)
        )
    }

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] {
        try await modelsService.fetchModels(apiKey: apiKey)
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        let requestBody = ChatCompletionsRequest(
            model: modelID,
            temperature: 0,
            messages: [
                .init(
                    role: "system",
                    content: OpenAIPromptBuilder.formatRecognizedTextSystemPrompt()
                ),
                .init(
                    role: "user",
                    content: OpenAIPromptBuilder.formatRecognizedTextUserPrompt(
                        targetLanguage: targetLanguage,
                        rawText: rawText
                    )
                )
            ]
        )

        let data = try await httpClient.post(
            path: "/chat/completions",
            apiKey: apiKey,
            body: requestBody
        )
        let decoded = try httpClient.decode(data, as: ChatCompletionsResponse.self)
        let content = decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            throw OpenAIServiceError.emptyFormattedText
        }

        let jsonString = Self.extractJSONObjectString(from: content) ?? content
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIServiceError.invalidStructuredResponse
        }
        let structured = try JSONDecoder().decode(StructuredResponseDTO.self, from: jsonData)
        let result = StructuredFormattedText(
            cleanedText: structured.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
            pinyinText: structured.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines),
            russianTranslation: structured.russianTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard result.hasContent else {
            throw OpenAIServiceError.emptyFormattedText
        }
        return result
    }

    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload {
        let prompt = OpenAIPromptBuilder.wordsAnalysisPrompt(for: targetLanguage)
        let dto: WordsResponseDTO = try await performStructuredRequest(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.2,
            systemPrompt: prompt.system,
            userPrompt: prompt.user(
                formattedText.cleanedText,
                formattedText.pinyinText,
                formattedText.russianTranslation
            )
        )
        let result = WordStudyPayload(
            entries: dto.entries.map {
                WordStudyEntry(
                    termPinyin: $0.termPinyin.trimmed,
                    termTranslation: $0.termTranslation.trimmed,
                    russianPronunciationGuide: ($0.russianPronunciation ?? "").trimmed,
                    characterBreakdown: $0.characterBreakdown.map {
                        CharacterMeaning(pinyinText: $0.pinyinText.trimmed, russianTranslation: $0.russianTranslation.trimmed)
                    }
                )
            }
        )
        guard result.hasContent else { throw OpenAIServiceError.invalidStructuredResponse }
        return result
    }

    func buildPhrasesStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> PhraseStudyPayload {
        let dto: PhrasesResponseDTO = try await performStructuredRequest(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.2,
            systemPrompt: OpenAIPromptBuilder.phrasesStudySystemPrompt(for: targetLanguage),
            userPrompt: OpenAIPromptBuilder.phrasesStudyUserPrompt(
                targetLanguage: targetLanguage,
                formattedText: formattedText
            )
        )
        let result = PhraseStudyPayload(entries: dto.entries.map { StudyListItem(pinyinText: $0.pinyinText.trimmed, russianTranslation: $0.russianTranslation.trimmed) })
        guard result.hasContent else { throw OpenAIServiceError.invalidStructuredResponse }
        return result
    }

    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload {
        let dto: GrammarResponseDTO = try await performStructuredRequest(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.2,
            systemPrompt: OpenAIPromptBuilder.grammarStudySystemPrompt(for: targetLanguage),
            userPrompt: OpenAIPromptBuilder.grammarStudyUserPrompt(
                targetLanguage: targetLanguage,
                formattedText: formattedText
            )
        )
        let result = GrammarExplanationPayload(
            structures: dto.structures.map {
                GrammarStructure(
                    title: $0.title.trimmed,
                    explanation: $0.explanation.trimmed,
                    usageNotes: $0.usageNotes.trimmed,
                    examples: $0.examples.map {
                        GrammarExample(pinyinText: $0.pinyinText.trimmed, russianTranslation: $0.russianTranslation.trimmed)
                    }
                )
            }
        )
        guard result.hasContent else { throw OpenAIServiceError.invalidStructuredResponse }
        return result
    }

    private static func extractJSONObjectString(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else { return nil }
        return String(content[start...end])
    }

    private func performStructuredRequest<Response: Decodable>(
        apiKey: String,
        modelID: String,
        temperature: Double,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> Response {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        let requestBody = ChatCompletionsRequest(
            model: modelID,
            temperature: temperature,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        let data = try await httpClient.post(
            path: "/chat/completions",
            apiKey: apiKey,
            body: requestBody
        )
        let decoded = try httpClient.decode(data, as: ChatCompletionsResponse.self)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { throw OpenAIServiceError.invalidStructuredResponse }
        let jsonString = Self.extractJSONObjectString(from: content) ?? content
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenAIServiceError.invalidStructuredResponse
        }
        return try JSONDecoder().decode(Response.self, from: jsonData)
    }
}

protocol OpenAITokenStoring {
    func loadToken() -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

enum OpenAITokenStoreError: LocalizedError {
    case unhandledError(OSStatus)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            return "Не удалось сохранить токен в Keychain (\(status))."
        case .invalidEncoding:
            return "Токен невозможно сохранить из-за ошибки кодировки."
        }
    }
}

struct KeychainOpenAITokenStore: OpenAITokenStoring {
    private let service = "local.llh.ocr.openai"
    private let account = "openai-api-token"

    func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw OpenAITokenStoreError.invalidEncoding
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw OpenAITokenStoreError.unhandledError(status)
        }
    }

    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OpenAITokenStoreError.unhandledError(status)
        }
    }
}

protocol OpenAISettingsStoring {
    var selectedModelID: String? { get set }
}

struct OpenAISettingsStore: OpenAISettingsStoring {
    private let userDefaults: UserDefaults
    private let selectedModelKey: String
    private let selectedLearningLanguageKey: String
    private let cachedModelsKey: String
    private let selectedOCREngineKey: String
    private let translationOverlayMinimumDurationKey: String
    private let translationOverlaySecondsPerWordKey: String

    init(
        userDefaults: UserDefaults = .standard,
        selectedModelKey: String = "openai.selected.model.id",
        selectedLearningLanguageKey: String = "openai.selected.learning.language",
        cachedModelsKey: String = "openai.cached.model.ids",
        selectedOCREngineKey: String = "ocr.selected.engine",
        translationOverlayMinimumDurationKey: String = "overlay.translation.minimum.duration",
        translationOverlaySecondsPerWordKey: String = "overlay.translation.seconds.per.word"
    ) {
        self.userDefaults = userDefaults
        self.selectedModelKey = selectedModelKey
        self.selectedLearningLanguageKey = selectedLearningLanguageKey
        self.cachedModelsKey = cachedModelsKey
        self.selectedOCREngineKey = selectedOCREngineKey
        self.translationOverlayMinimumDurationKey = translationOverlayMinimumDurationKey
        self.translationOverlaySecondsPerWordKey = translationOverlaySecondsPerWordKey
    }

    var selectedModelID: String? {
        get { userDefaults.string(forKey: selectedModelKey) }
        set { userDefaults.set(newValue, forKey: selectedModelKey) }
    }

    var selectedLearningLanguageRawValue: String {
        get { userDefaults.string(forKey: selectedLearningLanguageKey) ?? LearningLanguage.english.rawValue }
        set { userDefaults.set(newValue, forKey: selectedLearningLanguageKey) }
    }

    var cachedModels: [OpenAIModel] {
        get {
            let ids = userDefaults.stringArray(forKey: cachedModelsKey) ?? []
            return ids.map(OpenAIModel.init(id:))
        }
        set {
            userDefaults.set(newValue.map(\.id), forKey: cachedModelsKey)
        }
    }

    var selectedOCREngineRawValue: String {
        get { userDefaults.string(forKey: selectedOCREngineKey) ?? "local" }
        set { userDefaults.set(newValue, forKey: selectedOCREngineKey) }
    }

    var translationOverlayMinimumDuration: Double {
        get {
            let storedValue = userDefaults.double(forKey: translationOverlayMinimumDurationKey)
            if storedValue == 0 {
                return 3
            }
            return storedValue.clamped(to: 1...15)
        }
        set {
            userDefaults.set(newValue.clamped(to: 1...15), forKey: translationOverlayMinimumDurationKey)
        }
    }

    var translationOverlaySecondsPerWord: Double {
        get {
            let storedValue = userDefaults.double(forKey: translationOverlaySecondsPerWordKey)
            if storedValue == 0 {
                return 0.33
            }
            return storedValue.clamped(to: 0.1...2)
        }
        set {
            userDefaults.set(newValue.clamped(to: 0.1...2), forKey: translationOverlaySecondsPerWordKey)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [ChatMessage]
}

private struct VisionChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [VisionChatMessage]
}

private struct VisionChatMessage: Encodable {
    let role: String
    let content: [VisionChatContent]
}

private struct VisionChatContent: Encodable {
    let type: String
    let text: String?
    let imageURL: VisionImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    init(type: String, text: String? = nil, imageURL: VisionImageURL? = nil) {
        self.type = type
        self.text = text
        self.imageURL = imageURL
    }
}

private struct VisionImageURL: Encodable {
    let url: String
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [ChatChoice]
}

private struct VisionChatCompletionsResponse: Decodable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let message: ChatCompletionMessage
}

private struct ChatCompletionMessage: Decodable {
    let content: String
}

private struct StructuredResponseDTO: Decodable {
    let cleanedText: String
    let pinyinText: String
    let russianTranslation: String

    enum CodingKeys: String, CodingKey {
        case cleanedText = "cleaned_text"
        case pinyinText = "pinyin_text"
        case russianTranslation = "russian_translation"
    }
}

private struct StudyLineDTO: Decodable {
    let pinyinText: String
    let russianTranslation: String

    enum CodingKeys: String, CodingKey {
        case pinyinText = "pinyin_text"
        case russianTranslation = "russian_translation"
    }
}

private struct WordCharacterDTO: Decodable {
    let pinyinText: String
    let russianTranslation: String

    enum CodingKeys: String, CodingKey {
        case pinyinText = "pinyin_text"
        case russianTranslation = "russian_translation"
    }
}

private struct WordEntryDTO: Decodable {
    let termPinyin: String
    let termTranslation: String
    let russianPronunciation: String?
    let characterBreakdown: [WordCharacterDTO]

    enum CodingKeys: String, CodingKey {
        case termPinyin = "term_pinyin"
        case termTranslation = "term_translation"
        case russianPronunciation = "russian_pronunciation"
        case characterBreakdown = "character_breakdown"
    }
}

private struct WordsResponseDTO: Decodable {
    let entries: [WordEntryDTO]
}

private struct PhrasesResponseDTO: Decodable {
    let entries: [StudyLineDTO]
}

private struct GrammarStructureDTO: Decodable {
    let title: String
    let explanation: String
    let usageNotes: String
    let examples: [StudyLineDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case explanation
        case usageNotes = "usage_notes"
        case examples
    }
}

private struct GrammarResponseDTO: Decodable {
    let structures: [GrammarStructureDTO]
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension OpenAIService {
    static func jpegData(from image: CGImage, compressionQuality: CGFloat = 0.9) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}
