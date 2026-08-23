//
//  AITextRequestLogEntry.swift
//  llh
//

import Foundation

enum AITextRequestOperation: String, Sendable, Equatable {
    case formatRecognizedText
    case wordsStudy
    case translationChat

    var title: String {
        switch self {
        case .formatRecognizedText: "Форматирование и перевод"
        case .wordsStudy: "Разбор слов"
        case .translationChat: "Чат по переводу"
        }
    }
}

struct AITextRequestLogMessage: Equatable, Sendable {
    let role: String
    let content: String

    var displayRole: String {
        switch role {
        case "system": "Система"
        case "user": "Пользователь"
        case "assistant": "Ассистент"
        default: role
        }
    }
}

struct AITextRequestLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let operation: AITextRequestOperation
    let provider: AIProvider
    let modelID: String
    let messages: [AITextRequestLogMessage]
    let responseText: String?
    let errorDescription: String?
    let duration: TimeInterval

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        operation: AITextRequestOperation,
        provider: AIProvider,
        modelID: String,
        messages: [AITextRequestLogMessage],
        responseText: String?,
        errorDescription: String?,
        duration: TimeInterval
    ) {
        self.id = id
        self.createdAt = createdAt
        self.operation = operation
        self.provider = provider
        self.modelID = modelID
        self.messages = messages
        self.responseText = responseText
        self.errorDescription = errorDescription
        self.duration = duration
    }

    var didSucceed: Bool {
        errorDescription == nil
    }

    var plainTextReport: String {
        var lines: [String] = [
            "\(operation.title)",
            "Время: \(createdAt.formatted(date: .abbreviated, time: .standard))",
            "Провайдер: \(provider.title)",
            "Модель: \(modelID)",
            "Длительность: \(Self.formattedDuration(duration))",
            "Статус: \(didSucceed ? "успех" : "ошибка")"
        ]

        lines.append("")
        lines.append("Запрос:")
        for message in messages {
            lines.append("[\(message.displayRole)]")
            lines.append(message.content)
            lines.append("")
        }

        if let errorDescription {
            lines.append("Ошибка:")
            lines.append(errorDescription)
        } else {
            lines.append("Ответ:")
            lines.append(responseText ?? "")
        }

        return lines.joined(separator: "\n")
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        if duration < 10 {
            return String(format: "%.2f с", duration)
        }
        return String(format: "%.1f с", duration)
    }
}
