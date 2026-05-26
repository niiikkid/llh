//
//  OpenAIServiceError.swift
//  llh
//

import Foundation

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
    case invalidImageData
    case emptyRecognizedText

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
        case .invalidImageData:
            return "Не удалось подготовить изображение для распознавания."
        case .emptyRecognizedText:
            return "OpenAI не вернул распознанный текст."
        }
    }
}
