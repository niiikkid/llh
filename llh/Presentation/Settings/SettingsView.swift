//
//  SettingsView.swift
//  llh
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .general

    private enum SettingsTab: Hashable {
        case general
        case openAI
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                GeneralSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Общие", systemImage: "keyboard")
                    }
                    .tag(SettingsTab.general)

                OpenAISettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("OpenAI", systemImage: "brain.head.profile")
                    }
                    .tag(SettingsTab.openAI)
            }

            Divider()

            HStack {
                Spacer()
                Button("Закрыть") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 620, height: 420)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Горячие клавиши")
                    .font(.headline)

                Text("Настройте shortcut для захвата, переключения OCR, закрытия оверлея и показа последнего перевода.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                KeyboardShortcuts.Recorder("Захват области:", name: .captureArea)
                KeyboardShortcuts.Recorder("Переключить движок OCR:", name: .switchOCREngine)
                KeyboardShortcuts.Recorder("Закрыть компактное окно:", name: .closeTranslationOverlay)
                KeyboardShortcuts.Recorder("Показать или скрыть последний перевод:", name: .toggleLastTranslationOverlay)

                Divider()

                Text("Компактное окно перевода")
                    .font(.headline)

                Text("Когда приложение неактивно и перевод запущен через shortcut, снизу по центру появится маленькое окно. Время показа считается по формуле: максимум из минимального времени и `количество слов x секунд на слово`. Последний перевод можно открыть отдельной горячей клавишей и держать на экране, пока вы его сами не закроете.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 12) {
                    Stepper(
                        value: Binding(
                            get: { Int(viewModel.translationOverlayMinimumDuration.rounded()) },
                            set: { viewModel.setTranslationOverlayMinimumDuration(Double($0)) }
                        ),
                        in: 1...15
                    ) {
                        Text("Минимальное время: \(Int(viewModel.translationOverlayMinimumDuration.rounded())) сек.")
                    }
                    .frame(maxWidth: 280, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { viewModel.translationOverlayMinimumDuration },
                            set: { viewModel.setTranslationOverlayMinimumDuration($0) }
                        ),
                        in: 1...15,
                        step: 1
                    )
                }

                HStack(alignment: .center, spacing: 12) {
                    Stepper(
                        value: Binding(
                            get: { viewModel.translationOverlaySecondsPerWord },
                            set: { viewModel.setTranslationOverlaySecondsPerWord($0) }
                        ),
                        in: 0.1...2,
                        step: 0.01
                    ) {
                        Text("Секунд на слово: \(viewModel.translationOverlaySecondsPerWord, format: .number.precision(.fractionLength(2)))")
                    }
                    .frame(maxWidth: 280, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { viewModel.translationOverlaySecondsPerWord },
                            set: { viewModel.setTranslationOverlaySecondsPerWord($0) }
                        ),
                        in: 0.1...2,
                        step: 0.01
                    )
                }

                Text("Например: 10 слов x 0.33 = 3.3 сек. Если результат меньше минимума, используется минимум.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

private struct OpenAISettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var tokenInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Настройки OpenAI")
                    .font(.headline)

                Text("Вставьте API token, затем проверьте подключение. Токен сохраняется безопасно в Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if viewModel.hasOpenAIToken {
                    HStack(spacing: 12) {
                        Label("Токен подключен", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Удалить") {
                            tokenInput = ""
                            viewModel.deleteOpenAIToken()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.background.secondary)
                    )
                } else {
                    SecureField("sk-...", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 10) {
                    if !viewModel.hasOpenAIToken {
                        Button("Подключить") {
                            Task {
                                await viewModel.validateAndSaveOpenAIToken(tokenInput)
                                tokenInput = ""
                            }
                        }
                        .disabled(viewModel.isLoadingOpenAIModels || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Button("Обновить модели") {
                        Task {
                            await viewModel.refreshOpenAIModels()
                        }
                    }
                    .disabled(viewModel.isLoadingOpenAIModels || !viewModel.hasOpenAIToken)
                }

                if viewModel.isLoadingOpenAIModels {
                    ProgressView("Проверка подключения к OpenAI...")
                }

                Divider()

                Text("Модель")
                    .font(.subheadline.weight(.semibold))

                Picker(
                    "Модель OpenAI",
                    selection: Binding(
                        get: { viewModel.selectedOpenAIModelID },
                        set: { viewModel.selectOpenAIModel($0) }
                    )
                ) {
                    if viewModel.availableOpenAIModels.isEmpty {
                        Text("Список моделей пуст").tag(Optional<String>.none)
                    } else {
                        ForEach(viewModel.availableOpenAIModels) { model in
                            Text(model.id).tag(Optional(model.id))
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(viewModel.availableOpenAIModels.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .onAppear {
            tokenInput = ""
        }
    }
}
