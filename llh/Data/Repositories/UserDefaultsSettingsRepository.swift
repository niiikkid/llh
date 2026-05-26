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

    var selectedModelID: String? {
        get { store.selectedModelID }
        set { store.selectedModelID = newValue }
    }

    var selectedLearningLanguageRawValue: String {
        get { store.selectedLearningLanguageRawValue }
        set { store.selectedLearningLanguageRawValue = newValue }
    }

    var cachedModels: [OpenAIModel] {
        get { store.cachedModels }
        set { store.cachedModels = newValue }
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
