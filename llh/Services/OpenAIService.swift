//
//  OpenAIService.swift
//  llh
//

import Foundation
import Security

struct OpenAIModel: Identifiable, Equatable {
    let id: String
}

protocol OpenAIServing {
    func fetchModels(apiKey: String) async throws -> [OpenAIModel]
    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText
    func buildWordsStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> WordStudyPayload
    func buildPhrasesStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> PhraseStudyPayload
    func buildGrammarStudyData(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        formattedText: StructuredFormattedText
    ) async throws -> GrammarExplanationPayload
}

enum OpenAIServiceError: LocalizedError {
    case invalidTokenFormat
    case unauthorized
    case unexpectedStatusCode(Int)
    case invalidResponse
    case noModelsFound
    case hostNotFound
    case networkUnavailable
    case emptyFormattedText
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .invalidTokenFormat:
            return "Токен пустой или имеет неверный формат."
        case .unauthorized:
            return "Не удалось авторизоваться в OpenAI. Проверьте API token."
        case .unexpectedStatusCode(let code):
            return "OpenAI вернул ошибку (\(code))."
        case .invalidResponse:
            return "Получен некорректный ответ от OpenAI."
        case .noModelsFound:
            return "OpenAI не вернул доступные модели."
        case .hostNotFound:
            return "Не удается найти сервер OpenAI (DNS). Проверьте интернет, VPN/прокси и сетевые права приложения."
        case .networkUnavailable:
            return "Нет сетевого подключения. Проверьте интернет и повторите попытку."
        case .emptyFormattedText:
            return "OpenAI вернул пустой форматированный текст."
        case .invalidStructuredResponse:
            return "OpenAI вернул некорректную структуру форматированного текста."
        }
    }
}

struct OpenAIService: OpenAIServing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchModels(apiKey: String) async throws -> [OpenAIModel] {
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, token.hasPrefix("sk-") else {
            throw OpenAIServiceError.invalidTokenFormat
        }

        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw OpenAIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost, .dnsLookupFailed:
                throw OpenAIServiceError.hostNotFound
            case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff:
                throw OpenAIServiceError.networkUnavailable
            default:
                throw error
            }
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw OpenAIServiceError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        let models = decoded.data
            .map { OpenAIModel(id: $0.id) }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }

        guard !models.isEmpty else {
            throw OpenAIServiceError.noModelsFound
        }
        return models
    }

    func formatRecognizedText(
        apiKey: String,
        modelID: String,
        targetLanguage: LearningLanguage,
        rawText: String
    ) async throws -> StructuredFormattedText {
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, token.hasPrefix("sk-") else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIServiceError.invalidResponse
        }

        let requestBody = ChatCompletionsRequest(
            model: modelID,
            temperature: 0,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You clean OCR text for language learning and return JSON only.
                    Do not add any content that is absent in source except Russian translation.
                    Keep original symbols exactly for kept source fragments.
                    Remove noise and foreign language fragments.
                    Output strict JSON object with exactly 3 string fields:
                    cleaned_text
                    pinyin_text
                    russian_translation
                    No markdown, no code fences, no extra keys.
                    """
                ),
                .init(
                    role: "user",
                    content: """
                    Target language: \(targetLanguage.openAIInstructionName)
                    Rules:
                    \(targetLanguage.formattingRules)

                    Additional rules:
                    1) cleaned_text: cleaned source text in target language only.
                    2) pinyin_text: for Chinese provide pinyin for cleaned_text; for non-Chinese return empty string.
                    3) russian_translation: concise Russian translation of cleaned_text.

                    Raw OCR text:
                    \(rawText)
                    """
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost, .dnsLookupFailed:
                throw OpenAIServiceError.hostNotFound
            case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff:
                throw OpenAIServiceError.networkUnavailable
            default:
                throw error
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw OpenAIServiceError.unauthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
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
        let dto: WordsResponseDTO = try await performStructuredRequest(
            apiKey: apiKey,
            modelID: modelID,
            temperature: 0.2,
            systemPrompt: """
            You produce JSON only for language-learning word analysis.
            Never use hieroglyphs or source script in the response.
            Use only pinyin/transliteration and Russian.
            Return JSON object with key `entries`.
            Each entry has:
            term_pinyin
            term_translation
            character_breakdown
            `character_breakdown` is an array of objects with:
            pinyin_text
            russian_translation
            No markdown. No extra keys.
            """,
            userPrompt: """
            Target language: \(targetLanguage.openAIInstructionName)
            Cleaned text:
            \(formattedText.cleanedText)

            Pronunciation:
            \(formattedText.pinyinText)

            Translation:
            \(formattedText.russianTranslation)

            Extract only useful study words.
            For each word:
            1) give the full word in pinyin/transliteration and its Russian meaning
            2) if the word consists of multiple characters or meaningful parts, explain each part separately in `character_breakdown`
            3) keep the result compact and readable
            """
        )
        let result = WordStudyPayload(
            entries: dto.entries.map {
                WordStudyEntry(
                    termPinyin: $0.termPinyin.trimmed,
                    termTranslation: $0.termTranslation.trimmed,
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
            systemPrompt: """
            You produce JSON only for stable phrase extraction.
            Never use hieroglyphs or source script.
            Use only pinyin/transliteration and Russian.
            Return JSON object with key `entries`.
            Each item has:
            pinyin_text
            russian_translation
            Keep only stable or useful phrases, not isolated words.
            """,
            userPrompt: """
            Target language: \(targetLanguage.openAIInstructionName)
            Cleaned text:
            \(formattedText.cleanedText)

            Pronunciation:
            \(formattedText.pinyinText)

            Translation:
            \(formattedText.russianTranslation)

            Extract stable phrases or reusable chunks.
            """
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
            systemPrompt: """
            You produce JSON only for grammar explanation.
            Never use hieroglyphs or source script.
            Use only pinyin/transliteration and Russian.
            Return JSON object with key `structures`.
            Each structure has:
            title
            explanation
            usage_notes
            examples
            `examples` is an array of objects with:
            pinyin_text
            russian_translation
            Explain simply, compactly, and clearly.
            """,
            userPrompt: """
            Target language: \(targetLanguage.openAIInstructionName)
            Cleaned text:
            \(formattedText.cleanedText)

            Pronunciation:
            \(formattedText.pinyinText)

            Translation:
            \(formattedText.russianTranslation)

            Find grammar structures that may confuse a learner.
            For each structure:
            - explain what it means in simple Russian
            - explain where else it can be used
            - give short examples with transliteration only
            If there are multiple structures, return several.
            """
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
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, token.hasPrefix("sk-") else {
            throw OpenAIServiceError.invalidTokenFormat
        }
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost, .dnsLookupFailed:
                throw OpenAIServiceError.hostNotFound
            case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff:
                throw OpenAIServiceError.networkUnavailable
            default:
                throw error
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw OpenAIServiceError.unauthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
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
}

protocol OpenAISettingsStoring {
    var selectedModelID: String? { get set }
}

struct OpenAISettingsStore: OpenAISettingsStoring {
    private let userDefaults: UserDefaults
    private let selectedModelKey: String
    private let selectedLearningLanguageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        selectedModelKey: String = "openai.selected.model.id",
        selectedLearningLanguageKey: String = "openai.selected.learning.language"
    ) {
        self.userDefaults = userDefaults
        self.selectedModelKey = selectedModelKey
        self.selectedLearningLanguageKey = selectedLearningLanguageKey
    }

    var selectedModelID: String? {
        get { userDefaults.string(forKey: selectedModelKey) }
        set { userDefaults.set(newValue, forKey: selectedModelKey) }
    }

    var selectedLearningLanguageRawValue: String {
        get { userDefaults.string(forKey: selectedLearningLanguageKey) ?? LearningLanguage.english.rawValue }
        set { userDefaults.set(newValue, forKey: selectedLearningLanguageKey) }
    }
}

private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModelPayload]
}

private struct OpenAIModelPayload: Decodable {
    let id: String
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [ChatMessage]
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionsResponse: Decodable {
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
    let characterBreakdown: [WordCharacterDTO]

    enum CodingKeys: String, CodingKey {
        case termPinyin = "term_pinyin"
        case termTranslation = "term_translation"
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
