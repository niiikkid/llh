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
}

enum OpenAIServiceError: LocalizedError {
    case invalidTokenFormat
    case unauthorized
    case unexpectedStatusCode(Int)
    case invalidResponse
    case noModelsFound
    case hostNotFound
    case networkUnavailable

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

    init(userDefaults: UserDefaults = .standard, selectedModelKey: String = "openai.selected.model.id") {
        self.userDefaults = userDefaults
        self.selectedModelKey = selectedModelKey
    }

    var selectedModelID: String? {
        get { userDefaults.string(forKey: selectedModelKey) }
        set { userDefaults.set(newValue, forKey: selectedModelKey) }
    }
}

private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModelPayload]
}

private struct OpenAIModelPayload: Decodable {
    let id: String
}
