//
//  UserDefaultsSettingsRepository.swift
//  llh
//

import Foundation

final class UserDefaultsSettingsRepository: SettingsRepository {
    private var store: OpenAISettingsStore

    init(store: OpenAISettingsStore = OpenAISettingsStore()) {
        self.store = store
    }

    var selectedTextProviderRawValue: String {
        get { store.selectedTextProviderRawValue }
        set { store.selectedTextProviderRawValue = newValue }
    }

    var selectedModelID: String? {
        get { store.selectedModelID }
        set { store.selectedModelID = newValue }
    }

    var selectedDeepSeekModelID: String? {
        get { store.selectedDeepSeekModelID }
        set { store.selectedDeepSeekModelID = newValue }
    }

    var selectedLearningLanguageRawValue: String {
        get { store.selectedLearningLanguageRawValue }
        set { store.selectedLearningLanguageRawValue = newValue }
    }

    var cachedModels: [OpenAIModel] {
        get { store.cachedModels }
        set { store.cachedModels = newValue }
    }

    var cachedDeepSeekModels: [OpenAIModel] {
        get { store.cachedDeepSeekModels }
        set { store.cachedDeepSeekModels = newValue }
    }

    var selectedOCREngineRawValue: String {
        get { store.selectedOCREngineRawValue }
        set { store.selectedOCREngineRawValue = newValue }
    }

    var translationOverlayMinimumDuration: Double {
        get { store.translationOverlayMinimumDuration }
        set { store.translationOverlayMinimumDuration = newValue }
    }

    var translationOverlaySecondsPerWord: Double {
        get { store.translationOverlaySecondsPerWord }
        set { store.translationOverlaySecondsPerWord = newValue }
    }
}
