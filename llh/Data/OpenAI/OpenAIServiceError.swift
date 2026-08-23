//
//  OpenAIServiceError.swift
//  llh
//

import Foundation

enum OpenAIServiceError: LocalizedError, Equatable {
    case invalidTokenFormat
    case unauthorized
    case rateLimited
    case unexpectedStatusCode(Int)
    case invalidResponse
    case noModelsFound
    case hostNotFound
    case networkUnavailable
    case emptyFormattedText
    case invalidStructuredResponse
    case invalidImageData
    case emptyRecognizedText
    case emptyTranscription
    case emptyChatMessage
    case emptyChatReply
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidTokenFormat:
            return "Токен пустой или имеет неверный формат."
        case .unauthorized:
            return "Не удалось авторизоваться. Проверьте API-токен."
        case .rateLimited:
            return "Провайдер ИИ временно ограничил число запросов. Подождите и повторите попытку."
        case .unexpectedStatusCode(let code):
            return "Провайдер ИИ вернул ошибку (\(code))."
        case .invalidResponse:
            return "Получен некорректный ответ от провайдера ИИ."
        case .noModelsFound:
            return "Провайдер ИИ не вернул доступные модели."
        case .hostNotFound:
            return "Не удается найти сервер ИИ (DNS). Проверьте интернет, VPN/прокси и сетевые права приложения."
        case .networkUnavailable:
            return "Нет сетевого подключения. Проверьте интернет и повторите попытку."
        case .emptyFormattedText:
            return "Провайдер ИИ вернул пустой форматированный текст."
        case .invalidStructuredResponse:
            return "Провайдер ИИ вернул некорректную структуру форматированного текста."
        case .invalidImageData:
            return "Не удалось подготовить изображение для распознавания."
        case .emptyRecognizedText:
            return "OpenAI не вернул распознанный текст."
        case .emptyTranscription:
            return "Не удалось распознать речь. Надиктуйте ещё раз."
        case .emptyChatMessage:
            return "Сначала надиктуйте вопрос."
        case .emptyChatReply:
            return "Модель вернула пустой ответ."
        case .timeout:
            return "Превышено время ожидания ответа от провайдера ИИ. Проверьте сеть и повторите попытку."
        case .cancelled:
            return "Запрос к провайдеру ИИ был отменён."
        }
    }
}
