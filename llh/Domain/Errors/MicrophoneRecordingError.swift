//
//  MicrophoneRecordingError.swift
//  llh
//

import Foundation

enum MicrophoneRecordingError: LocalizedError, Equatable {
    case permissionDenied
    case recordingFailed
    case noAudioRecorded

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Нет доступа к микрофону. Разрешите его в системных настройках конфиденциальности."
        case .recordingFailed:
            return "Не удалось начать запись голоса."
        case .noAudioRecorded:
            return "Запись получилась пустой. Надиктуйте ещё раз."
        }
    }
}
