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
    @State private var selectedTextTab: TextTab = .raw
    @State private var newProfileName = ""
    @State private var isCreateProfilePresented = false
    @State private var isDeleteProfileConfirmationPresented = false
    @State private var isOpenAISettingsPresented = false

    private enum TextTab: String, Hashable {
        case raw
        case formatted
    }

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

                        Picker(
                            "Язык изучения",
                            selection: Binding(
                                get: { viewModel.selectedLearningLanguage },
                                set: { viewModel.selectLearningLanguage($0) }
                            )
                        ) {
                            ForEach(LearningLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)

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
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Режим текста", selection: $selectedTextTab) {
                                Text("Сырой текст").tag(TextTab.raw)
                                Text("Форматированный").tag(TextTab.formatted)
                            }
                            .pickerStyle(.segmented)

                            if selectedTextTab == .raw {
                                TextEditor(
                                    text: Binding(
                                        get: { viewModel.recognizedText },
                                        set: { viewModel.updateSelectedText($0) }
                                    )
                                )
                                .font(.system(.body, design: .monospaced))
                            } else {
                                formattedTextContent
                            }
                        }
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

    @ViewBuilder
    private var formattedTextContent: some View {
        if let formatted = viewModel.formattedRecognizedText, formatted.hasContent {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 18) {
                        Text(formatted.cleanedText)
                            .font(.system(size: 26, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)

                        Text(formatted.pinyinText.isEmpty ? "—" : formatted.pinyinText)
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)

                        Text(formatted.russianTranslation)
                            .font(.system(size: 26, weight: .regular, design: .default))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.background.secondary)
                    )

                    studyAssistantBlock
                }
                .padding(12)
            }
        } else if viewModel.isFormattingRecognizedText || viewModel.selectedEntryFormattingStatus == .processing {
            ContentUnavailableView(
                "Форматирую текст",
                systemImage: "wand.and.stars",
                description: Text("Подождите, запрос в OpenAI выполняется.")
            )
        } else if viewModel.canRetryFormatting {
            VStack(alignment: .leading, spacing: 10) {
                ContentUnavailableView(
                    "Форматирование не удалось",
                    systemImage: "exclamationmark.arrow.trianglehead.counterclockwise",
                    description: Text("Можно отправить запрос в OpenAI повторно.")
                )
                Button("Попробовать еще раз") {
                    viewModel.retryFormattingForSelectedEntry()
                }
                .disabled(viewModel.isFormattingRecognizedText)
            }
        } else {
            ContentUnavailableView(
                "Форматированного текста пока нет",
                systemImage: "doc.text",
                description: Text("Сырой текст сохранен, форматирование недоступно для этой записи.")
            )
        }
    }

    @ViewBuilder
    private var studyAssistantBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(
                "Дополнительные материалы",
                selection: Binding(
                    get: { viewModel.selectedStudyAssistantTab },
                    set: { viewModel.selectStudyAssistantTab($0) }
                )
            ) {
                ForEach(StudyAssistantTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            studyAssistantContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background.secondary)
        )
    }

    @ViewBuilder
    private var studyAssistantContent: some View {
        if viewModel.isLoadingStudyAssistantData || viewModel.selectedEntryStudyAssistantStatus == .processing {
            ContentUnavailableView(
                "Готовлю материалы",
                systemImage: "books.vertical",
                description: Text("Запрашиваю слова, фразы и объяснение грамматики.")
            )
        } else if let data = viewModel.studyAssistantData, data.hasContent {
            switch viewModel.selectedStudyAssistantTab {
            case .words:
                studyListView(data.words, emptyTitle: "Слова не найдены")
            case .phrases:
                studyListView(data.phrases, emptyTitle: "Устойчивые фразы не найдены")
            case .grammar:
                grammarView(data.grammar)
            }
        } else if viewModel.canRetryStudyAssistantData {
            VStack(alignment: .leading, spacing: 10) {
                ContentUnavailableView(
                    "Материалы не загрузились",
                    systemImage: "arrow.clockwise.circle",
                    description: Text("Можно запросить слова, фразы и грамматику еще раз.")
                )
                Button("Попробовать еще раз") {
                    viewModel.retryStudyAssistantDataForSelectedEntry()
                }
                .disabled(viewModel.isLoadingStudyAssistantData)
            }
        } else {
            ContentUnavailableView(
                "Материалы еще не готовы",
                systemImage: "text.book.closed",
                description: Text("Откройте вкладку повторно после завершения форматирования.")
            )
        }
    }

    @ViewBuilder
    private func studyListView(_ items: [StudyListItem], emptyTitle: String) -> some View {
        if items.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "list.bullet.rectangle",
                description: Text("Для этой записи AI не выделил элементов.")
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.pinyinText)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        Text(item.russianTranslation)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func grammarView(_ grammar: GrammarExplanation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !grammar.summary.isEmpty {
                Text(grammar.summary)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            if !grammar.examples.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Примеры")
                        .font(.headline)
                    ForEach(Array(grammar.examples.enumerated()), id: \.offset) { _, example in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.pinyinText)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                            Text(example.russianTranslation)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Divider()
                    }
                }
            }
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
