//
//  OpenAISettingsStore.swift
//  llh
//

import Foundation

protocol OpenAISettingsStoring {
    var selectedModelID: String? { get set }
}

struct OpenAISettingsStore: OpenAISettingsStoring {
    private let userDefaults: UserDefaults
    private let selectedTextProviderKey: String
    private let selectedModelKey: String
    private let selectedDeepSeekModelKey: String
    private let selectedLearningLanguageKey: String
    private let cachedModelsKey: String
    private let cachedDeepSeekModelsKey: String
    private let selectedOCREngineKey: String
    private let translationOverlayMinimumDurationKey: String
    private let translationOverlaySecondsPerWordKey: String

    init(
        userDefaults: UserDefaults = .standard,
        selectedTextProviderKey: String = "ai.text.provider",
        selectedModelKey: String = "openai.selected.model.id",
        selectedDeepSeekModelKey: String = "deepseek.selected.model.id",
        selectedLearningLanguageKey: String = "openai.selected.learning.language",
        cachedModelsKey: String = "openai.cached.model.ids",
        cachedDeepSeekModelsKey: String = "deepseek.cached.model.ids",
        selectedOCREngineKey: String = "ocr.selected.engine",
        translationOverlayMinimumDurationKey: String = "overlay.translation.minimum.duration",
        translationOverlaySecondsPerWordKey: String = "overlay.translation.seconds.per.word"
    ) {
        self.userDefaults = userDefaults
        self.selectedTextProviderKey = selectedTextProviderKey
        self.selectedModelKey = selectedModelKey
        self.selectedDeepSeekModelKey = selectedDeepSeekModelKey
        self.selectedLearningLanguageKey = selectedLearningLanguageKey
        self.cachedModelsKey = cachedModelsKey
        self.cachedDeepSeekModelsKey = cachedDeepSeekModelsKey
        self.selectedOCREngineKey = selectedOCREngineKey
        self.translationOverlayMinimumDurationKey = translationOverlayMinimumDurationKey
        self.translationOverlaySecondsPerWordKey = translationOverlaySecondsPerWordKey
    }

    var selectedTextProviderRawValue: String {
        get { userDefaults.string(forKey: selectedTextProviderKey) ?? AIProvider.openAI.rawValue }
        set { userDefaults.set(newValue, forKey: selectedTextProviderKey) }
    }

    var selectedDeepSeekModelID: String? {
        get { userDefaults.string(forKey: selectedDeepSeekModelKey) }
        set { userDefaults.set(newValue, forKey: selectedDeepSeekModelKey) }
    }

    var cachedDeepSeekModels: [OpenAIModel] {
        get {
            let ids = userDefaults.stringArray(forKey: cachedDeepSeekModelsKey) ?? []
            return ids.map(OpenAIModel.init(id:))
        }
        set {
            userDefaults.set(newValue.map(\.id), forKey: cachedDeepSeekModelsKey)
        }
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
