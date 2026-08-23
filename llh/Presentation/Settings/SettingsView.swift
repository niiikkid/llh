//
//  SettingsView.swift
//  llh
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .general

    private enum SettingsTab: Hashable {
        case general
        case intelligence
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Общие", systemImage: "keyboard")
                }
                .tag(SettingsTab.general)

            IntelligenceSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("ИИ", systemImage: "brain.head.profile")
                }
                .tag(SettingsTab.intelligence)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Горячие клавиши") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Настройте shortcut для захвата, переключения OCR, закрытия оверлея и показа последнего перевода."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        SettingsShortcutRow(
                            title: "Захват области",
                            shortcut: .captureArea
                        )
                        SettingsShortcutRow(
                            title: "Переключить движок OCR",
                            shortcut: .switchOCREngine
                        )
                        SettingsShortcutRow(
                            title: "Закрыть компактное окно",
                            shortcut: .closeTranslationOverlay
                        )
                        SettingsShortcutRow(
                            title: "Показать или скрыть последний перевод",
                            shortcut: .toggleLastTranslationOverlay
                        )
                    }
                }
                .groupBoxStyle(PanelGroupBoxStyle())

                GroupBox("Компактное окно перевода") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(
                            "Когда приложение неактивно и перевод запущен через shortcut, снизу по центру появится маленькое окно. Пока идёт обработка, окно остаётся до ручного закрытия (кнопка ✕ или Escape). Готовый перевод скрывается по таймеру: максимум из минимального времени и «количество слов × секунд на слово», если для сессии не включено «Показывать перевод слов в компактном окне» — тогда окно остаётся открытым, пока вы его не закроете, и может показать перевод слов под основным текстом. Последний перевод можно открыть отдельной горячей клавишей и держать на экране, пока вы его сами не закроете. Если для той сессии включено «Показывать перевод слов в компактном окне», под переводом появятся те же слова, что и в классическом компактном окне."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        SettingsDurationSliderRow(
                            title: "Минимальное время",
                            valueText: "\(Int(viewModel.translationOverlayMinimumDuration.rounded())) сек.",
                            value: Binding(
                                get: { viewModel.translationOverlayMinimumDuration },
                                set: { viewModel.setTranslationOverlayMinimumDuration($0) }
                            ),
                            range: 1...15,
                            step: 1
                        )

                        SettingsDurationSliderRow(
                            title: "Секунд на слово",
                            valueText: viewModel.translationOverlaySecondsPerWord.formatted(
                                .number.precision(.fractionLength(2))
                            ),
                            value: Binding(
                                get: { viewModel.translationOverlaySecondsPerWord },
                                set: { viewModel.setTranslationOverlaySecondsPerWord($0) }
                            ),
                            range: 0.1...2,
                            step: 0.01
                        )

                        Text(
                            "Например: 10 слов × 0.33 = 3.3 сек. Если результат меньше минимума, используется минимум."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .groupBoxStyle(PanelGroupBoxStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Intelligence

private struct IntelligenceSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var openAITokenInput = ""
    @State private var deepSeekTokenInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Провайдер текста") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Перевод, форматирование и учебные материалы идут через выбранного провайдера. Распознавание изображений (AI OCR) всегда использует OpenAI."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        SettingsLabeledControlRow(title: "Провайдер") {
                            Picker(
                                "Провайдер",
                                selection: Binding(
                                    get: { viewModel.selectedTextProvider },
                                    set: { viewModel.selectTextProvider($0) }
                                )
                            ) {
                                ForEach(AIProvider.allCases) { provider in
                                    Text(provider.title).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 320, alignment: .leading)
                        }
                    }
                }
                .groupBoxStyle(PanelGroupBoxStyle())

                ProviderConnectionBox(
                    provider: .openAI,
                    caption: "Нужен для AI OCR и для текста, если выбран OpenAI. Токен хранится в Keychain.",
                    hasToken: viewModel.hasOpenAIToken,
                    tokenInput: $openAITokenInput,
                    isLoading: viewModel.isLoadingModels,
                    onConnect: {
                        await viewModel.validateAndSaveToken(openAITokenInput, for: .openAI)
                        openAITokenInput = ""
                    },
                    onRefresh: {
                        await viewModel.refreshModels(for: .openAI)
                    },
                    onDelete: {
                        openAITokenInput = ""
                        viewModel.deleteToken(for: .openAI)
                    }
                )

                ProviderConnectionBox(
                    provider: .deepSeek,
                    caption: "Нужен для перевода и учебных материалов, если выбран DeepSeek. Скриншоты в DeepSeek не отправляются.",
                    hasToken: viewModel.hasDeepSeekToken,
                    tokenInput: $deepSeekTokenInput,
                    isLoading: viewModel.isLoadingModels,
                    onConnect: {
                        await viewModel.validateAndSaveToken(deepSeekTokenInput, for: .deepSeek)
                        deepSeekTokenInput = ""
                    },
                    onRefresh: {
                        await viewModel.refreshModels(for: .deepSeek)
                    },
                    onDelete: {
                        deepSeekTokenInput = ""
                        viewModel.deleteToken(for: .deepSeek)
                    }
                )

                GroupBox("Модель") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsLabeledControlRow(title: "Модель \(viewModel.selectedTextProvider.title)") {
                            Picker(
                                "Модель",
                                selection: Binding(
                                    get: { viewModel.selectedTextModelID },
                                    set: { viewModel.selectTextModel($0) }
                                )
                            ) {
                                if viewModel.availableTextModels.isEmpty {
                                    Text("Список моделей пуст").tag(Optional<String>.none)
                                } else {
                                    ForEach(viewModel.availableTextModels) { model in
                                        Text(model.id).tag(Optional(model.id))
                                    }
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 320, alignment: .leading)
                            .disabled(viewModel.availableTextModels.isEmpty)
                        }

                        if viewModel.isLoadingModels {
                            ProgressView("Проверка подключения...")
                        }

                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .groupBoxStyle(PanelGroupBoxStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            openAITokenInput = ""
            deepSeekTokenInput = ""
        }
    }
}

private struct ProviderConnectionBox: View {
    let provider: AIProvider
    let caption: String
    let hasToken: Bool
    @Binding var tokenInput: String
    let isLoading: Bool
    let onConnect: () async -> Void
    let onRefresh: () async -> Void
    let onDelete: () -> Void

    var body: some View {
        GroupBox(provider.title) {
            VStack(alignment: .leading, spacing: 12) {
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if hasToken {
                    HStack(spacing: 12) {
                        Label("Токен подключен", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Удалить", action: onDelete)
                            .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.quaternary.opacity(0.5))
                    )
                } else {
                    SecureField("sk-...", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 480)
                }

                HStack(spacing: 10) {
                    if !hasToken {
                        Button("Подключить") {
                            Task { await onConnect() }
                        }
                        .disabled(
                            isLoading
                                || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }

                    Button("Обновить модели") {
                        Task { await onRefresh() }
                    }
                    .disabled(isLoading || !hasToken)
                }
            }
        }
        .groupBoxStyle(PanelGroupBoxStyle())
    }
}

// MARK: - Shared rows

private struct SettingsShortcutRow: View {
    let title: String
    let shortcut: KeyboardShortcuts.Name

    var body: some View {
        SettingsLabeledControlRow(title: title) {
            KeyboardShortcuts.Recorder("", name: shortcut)
                .frame(maxWidth: 320, alignment: .leading)
        }
    }
}

private struct SettingsLabeledControlRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: () -> Control

    private let labelWidth: CGFloat = 280

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .frame(width: labelWidth, alignment: .leading)
            control()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsDurationSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        SettingsLabeledControlRow(title: title) {
            HStack(spacing: 12) {
                Text(valueText)
                    .monospacedDigit()
                    .frame(width: 88, alignment: .leading)

                Slider(value: $value, in: range, step: step)
                    .frame(minWidth: 160, maxWidth: 360)
            }
        }
    }
}
