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
        case openAI
    }

    var body: some View {
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
                            "Когда приложение неактивно и перевод запущен через shortcut, снизу по центру появится маленькое окно. Пока идёт обработка, окно остаётся до ручного закрытия (кнопка ✕ или Escape). Готовый перевод скрывается по таймеру: максимум из минимального времени и «количество слов × секунд на слово». Последний перевод можно открыть отдельной горячей клавишей и держать на экране, пока вы его сами не закроете."
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

// MARK: - OpenAI

private struct OpenAISettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var tokenInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Подключение") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Вставьте API token, затем проверьте подключение. Токен сохраняется безопасно в Keychain."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

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
                            if !viewModel.hasOpenAIToken {
                                Button("Подключить") {
                                    Task {
                                        await viewModel.validateAndSaveOpenAIToken(tokenInput)
                                        tokenInput = ""
                                    }
                                }
                                .disabled(
                                    viewModel.isLoadingOpenAIModels
                                        || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
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

                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .groupBoxStyle(PanelGroupBoxStyle())

                GroupBox("Модель") {
                    SettingsLabeledControlRow(title: "Модель OpenAI") {
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
                        .frame(maxWidth: 320, alignment: .leading)
                        .disabled(viewModel.availableOpenAIModels.isEmpty)
                    }
                }
                .groupBoxStyle(PanelGroupBoxStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            tokenInput = ""
        }
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
