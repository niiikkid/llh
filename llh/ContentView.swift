//
//  ContentView.swift
//  llh
//
//  Created by itsme on 06.04.2026.
//

import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var newProfileName = ""
    @State private var isCreateProfilePresented = false
    @State private var isDeleteProfileConfirmationPresented = false
    @State private var isOpenAISettingsPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language Learning Helper")
                .font(.title3.weight(.semibold))

            Text("Все данные обрабатываются локально на устройстве.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Shortcut") {
                HStack {
                    KeyboardShortcuts.Recorder("Capture area:", name: .captureArea)
                    Spacer()
                    Button("OpenAI Settings") {
                        isOpenAISettingsPresented = true
                    }
                    Button("Capture now") {
                        viewModel.triggerCapture()
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            if viewModel.showPermissionHelp {
                GroupBox("Нужно разрешение Screen Recording") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Откройте System Settings -> Privacy & Security -> Screen Recording и включите доступ для приложения.")
                        HStack {
                            Button("Open System Settings") {
                                viewModel.openSystemSettings()
                            }
                            Button("Проверить снова") {
                                viewModel.refreshPermissionState()
                            }
                            .disabled(viewModel.isProcessing)
                        }
                    }
                    .font(.callout)
                }
            }

            HStack {
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HSplitView {
                GroupBox("История") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Picker(
                                "Профиль",
                                selection: Binding(
                                    get: { viewModel.selectedProfileID },
                                    set: { viewModel.selectProfile($0) }
                                )
                            ) {
                                ForEach(viewModel.profiles) { profile in
                                    Text(profile.name).tag(Optional(profile.id))
                                }
                            }
                            .labelsHidden()

                            Button {
                                newProfileName = ""
                                isCreateProfilePresented = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .help("Создать профиль")

                            Button(role: .destructive) {
                                isDeleteProfileConfirmationPresented = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help("Удалить текущий профиль")
                            .disabled(!viewModel.canDeleteSelectedProfile)

                            Button(role: .destructive) {
                                viewModel.deleteSelectedEntry()
                            } label: {
                                Image(systemName: "trash.slash")
                            }
                            .help("Удалить выбранный перевод")
                            .disabled(!viewModel.canDeleteSelectedEntry)
                        }

                        if viewModel.history.isEmpty {
                            ContentUnavailableView(
                                "Пока пусто",
                                systemImage: "clock.arrow.circlepath",
                                description: Text("После захвата текста записи появятся здесь.")
                            )
                        } else {
                            List(
                                viewModel.history,
                                selection: Binding(
                                    get: { viewModel.selectedEntryID },
                                    set: { viewModel.selectEntry($0) }
                                )
                            ) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Text(viewModel.formattedDate(for: item.createdAt))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .tag(item.id)
                            }
                            .listStyle(.sidebar)
                        }
                    }
                }
                .frame(minWidth: 280, idealWidth: 320)

                GroupBox("Текст записи") {
                    if viewModel.selectedEntryID == nil {
                        ContentUnavailableView(
                            "Выберите запись",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Слева выберите элемент истории, чтобы открыть полный текст.")
                        )
                    } else {
                        TextEditor(
                            text: Binding(
                                get: { viewModel.recognizedText },
                                set: { viewModel.updateSelectedText($0) }
                            )
                        )
                        .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(minWidth: 480)
            }
            .frame(minHeight: 320)
            .overlay {
                if viewModel.isProcessing {
                    ProgressView()
                }
            }
        }
        .padding(16)
        .frame(minWidth: 860, minHeight: 500)
        .sheet(isPresented: $isCreateProfilePresented) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Новый профиль")
                    .font(.headline)
                TextField("Название профиля", text: $newProfileName)
                HStack {
                    Spacer()
                    Button("Отмена") {
                        isCreateProfilePresented = false
                    }
                    Button("Создать") {
                        viewModel.createProfile(named: newProfileName)
                        isCreateProfilePresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 360)
        }
        .sheet(isPresented: $isOpenAISettingsPresented) {
            OpenAISettingsSheet(viewModel: viewModel)
        }
        .alert("Удалить профиль?", isPresented: $isDeleteProfileConfirmationPresented) {
            Button("Удалить", role: .destructive) {
                viewModel.deleteSelectedProfile()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Профиль \"\(viewModel.selectedProfileName)\" будет удален вместе со всей историей внутри него.")
        }
    }
}

private struct OpenAISettingsSheet: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tokenInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Настройки OpenAI")
                .font(.headline)

            Text("Вставьте API token, затем проверьте подключение. Токен сохраняется безопасно в Keychain.")
                .font(.callout)
                .foregroundStyle(.secondary)

            SecureField("sk-...", text: $tokenInput)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Проверить и сохранить token") {
                    Task {
                        await viewModel.validateAndSaveOpenAIToken(tokenInput)
                    }
                }
                .disabled(viewModel.isLoadingOpenAIModels)

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

            HStack {
                Spacer()
                Button("Закрыть") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}

#Preview {
    ContentView(viewModel: MainViewModel())
}
