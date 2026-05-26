//
//  SettingsRepository.swift
//  llh
//

import Foundation

protocol SettingsRepository {
    var selectedModelID: String? { get set }
    var selectedLearningLanguageRawValue: String { get set }
    var cachedModels: [OpenAIModel] { get set }
    var selectedOCREngineRawValue: String { get set }
    var translationOverlayMinimumDuration: Double { get set }
    var translationOverlaySecondsPerWord: Double { get set }
}
