//
//  ContentView.swift
//  llh
//
//  Created by itsme on 06.04.2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedTextTab: TextTab = .formatted
    @State private var isSessionsPanelCollapsed = false
    @State private var newProfileName = ""
    @State private var newProfileLearningLanguage: LearningLanguage = .english
    @State private var isCreateProfilePresented = false
    @State private var isDeleteProfileConfirmationPresented = false
    @State private var isSettingsPresented = false
    @State private var sessionReadingFontSizePoints: CGFloat = 16

    private enum TextTab: String, Hashable {
        case raw
        case formatted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Language Learning Helper")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker(
                    "Движок OCR",
                    selection: Binding(
                        get: { viewModel.settings.selectedOCREngine },
                        set: { viewModel.settings.selectOCREngine($0) }
                    )
                ) {
                    ForEach(OCREngine.allCases) { engine in
                        Text(engine.title).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                Button {
                    isSessionsPanelCollapsed.toggle()
                } label: {
                    Label(
                        isSessionsPanelCollapsed ? "Показать сессии" : "Скрыть сессии",
                        systemImage: isSessionsPanelCollapsed ? "sidebar.left" : "sidebar.leading"
                    )
                }
                .buttonStyle(.bordered)
                Button {
                    isSettingsPresented = true
                } label: {
                    Label("Настройки", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
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

            GeometryReader { geometry in
                let columnSpacing: CGFloat = 12
                let detailMinimumWidth: CGFloat = 420
                let sidebarMinimumWidth: CGFloat = 280
                let spacing = isSessionsPanelCollapsed ? 0 : columnSpacing
                let availableWidth = max(geometry.size.width - spacing, 0)
                let sidebarWidth = min(
                    max(sidebarMinimumWidth, availableWidth * 0.25),
                    max(sidebarMinimumWidth, availableWidth - detailMinimumWidth)
                )

                HStack(alignment: .top, spacing: spacing) {
                    if !isSessionsPanelCollapsed {
                        GroupBox("Сессии") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Picker(
                                        "Сессия",
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

                                    sidebarActionButton(systemName: "plus", helpText: "Создать сессию") {
                                        newProfileName = ""
                                        newProfileLearningLanguage = viewModel.settings.defaultNewProfileLearningLanguage
                                        isCreateProfilePresented = true
                                    }

                                    sidebarActionButton(
                                        systemName: "trash",
                                        helpText: "Удалить текущую сессию",
                                        role: .destructive
                                    ) {
                                        isDeleteProfileConfirmationPresented = true
                                    }
                                    .disabled(!viewModel.canDeleteSelectedProfile)
                                }

                                HStack(spacing: 8) {
                                    Text("Язык сессии:")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(viewModel.currentProfileLearningLanguage.title)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(.background.secondary)
                                        )
                                    Spacer()
                                }

                                if viewModel.currentProfileLearningLanguage == .auto {
                                    Text("Для этой сессии язык определяется автоматически, отображается только перевод.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if viewModel.history.isEmpty {
                                    ContentUnavailableView(
                                        "Пока пусто",
                                        systemImage: "clock.arrow.circlepath",
                                        description: Text("После захвата текста переводы появятся здесь.")
                                    )
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Button {
                                                viewModel.toggleSessionReadingOverview()
                                            } label: {
                                                Label(
                                                    viewModel.showsSessionReadingOverview
                                                        ? "К списку переводов"
                                                        : "Весь текст сессии",
                                                    systemImage: viewModel.showsSessionReadingOverview
                                                        ? "list.bullet.rectangle"
                                                        : "doc.plaintext"
                                                )
                                            }
                                            .buttonStyle(.bordered)
                                            .help(
                                                viewModel.showsSessionReadingOverview
                                                    ? "Вернуться к выбранному переводу в списке."
                                                    : "Показать все фрагменты сессии подряд: строка оригинала и строка перевода."
                                            )
                                            Spacer()
                                        }

                                        List(
                                            viewModel.history,
                                            selection: Binding(
                                                get: { viewModel.selectedEntryID },
                                                set: { viewModel.selectEntry($0) }
                                            )
                                        ) { item in
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack(alignment: .firstTextBaseline) {
                                                    Text(
                                                        item.sessionListTitleLine(
                                                            learningLanguage: viewModel.currentProfileLearningLanguage
                                                        )
                                                    )
                                                        .font(.subheadline.weight(.semibold))
                                                        .lineLimit(1)
                                                    Spacer(minLength: 8)
                                                    Text(viewModel.formattedDate(for: item.createdAt))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text(item.sessionListPreviewLine())
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                            .padding(.vertical, 4)
                                            .tag(item.id)
                                        }
                                        .listStyle(.sidebar)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                            }
                        }
                        .groupBoxStyle(PanelGroupBoxStyle())
                        .frame(
                            minWidth: sidebarWidth,
                            idealWidth: sidebarWidth,
                            maxWidth: sidebarWidth,
                            maxHeight: .infinity
                        )
                    }

                    GroupBox {
                        if viewModel.showsSessionReadingOverview {
                            if viewModel.history.isEmpty {
                                centeredContent {
                                    ContentUnavailableView(
                                        "Пока пусто",
                                        systemImage: "doc.plaintext",
                                        description: Text("В этой сессии ещё нет переводов.")
                                    )
                                }
                            } else {
                                sessionReadingOverviewPanel
                            }
                        } else if viewModel.selectedEntryID == nil {
                            centeredContent {
                                ContentUnavailableView(
                                    "Выберите перевод",
                                    systemImage: "doc.text.magnifyingglass",
                                    description: Text("Слева выберите перевод из сессии, чтобы открыть полный текст.")
                                )
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("", selection: $selectedTextTab) {
                                    Text("Сырой текст").tag(TextTab.raw)
                                    Text("Форматированный").tag(TextTab.formatted)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                Group {
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
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                                HStack {
                                    Spacer()
                                    Button(role: .destructive) {
                                        viewModel.deleteSelectedEntry()
                                    } label: {
                                        Label("Удалить перевод", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!viewModel.canDeleteSelectedEntry)
                                }
                            }
                        }
                    } label: {
                        Text(viewModel.showsSessionReadingOverview ? "Вся сессия" : "Перевод")
                    }
                    .groupBoxStyle(PanelGroupBoxStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                }
            }
            .frame(minHeight: 320)
            .overlay {
                if viewModel.isProcessing {
                    ProgressView()
                }
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 500)
        .sheet(isPresented: $isCreateProfilePresented) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Новая сессия")
                    .font(.headline)
                TextField("Название сессии", text: $newProfileName)
                Picker("Язык изучения", selection: $newProfileLearningLanguage) {
                    ForEach(LearningLanguage.allCases.filter(\.supportsWordStudy)) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Spacer()
                    Button("Отмена") {
                        isCreateProfilePresented = false
                    }
                    Button("Создать") {
                        viewModel.createProfile(
                            named: newProfileName,
                            learningLanguage: newProfileLearningLanguage
                        )
                        isCreateProfilePresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 360)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel.settings)
        }
        .alert("Удалить сессию?", isPresented: $isDeleteProfileConfirmationPresented) {
            Button("Удалить", role: .destructive) {
                viewModel.deleteSelectedProfile()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сессия \"\(viewModel.selectedProfileName)\" будет удалена вместе со всеми переводами внутри нее.")
        }
    }

    @ViewBuilder
    private var formattedTextContent: some View {
        if let formatted = viewModel.formattedRecognizedText, formatted.hasContent {
            VStack(spacing: 12) {
                formattedTranslationBlock(formatted)
                if viewModel.currentProfileSupportsWordStudy {
                    studyAssistantBlock
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if viewModel.isFormattingRecognizedText || viewModel.selectedEntryFormattingStatus == .processing {
            centeredContent {
                ContentUnavailableView(
                    "Форматирую текст",
                    systemImage: "wand.and.stars",
                    description: Text("Подождите, запрос в OpenAI выполняется.")
                )
            }
        } else if viewModel.canRetryFormatting {
            centeredContent {
                VStack(alignment: .center, spacing: 10) {
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
            }
        } else {
            centeredContent {
                ContentUnavailableView(
                    "Форматированного текста пока нет",
                    systemImage: "doc.text",
                    description: Text("Сырой текст сохранен, форматирование недоступно для этой записи.")
                )
            }
        }
    }

    @ViewBuilder
    private var sessionReadingOverviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    viewModel.copySessionReadingOverviewToPasteboard()
                } label: {
                    Label("Копировать весь текст", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Скопировать все фрагменты сессии в буфер обмена.")

                Spacer(minLength: 0)
                Button {
                    sessionReadingFontSizePoints = max(12, sessionReadingFontSizePoints - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(sessionReadingFontSizePoints <= 12)
                .help("Уменьшить размер текста")

                Button {
                    sessionReadingFontSizePoints = min(24, sessionReadingFontSizePoints + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(sessionReadingFontSizePoints >= 24)
                .help("Увеличить размер текста")
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(viewModel.sessionReadingSequence.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            if item.sourceLine.isEmpty {
                                Text(item.displaySourceLine)
                                    .font(.system(size: sessionReadingFontSizePoints))
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(item.sourceLine)
                                    .font(.system(size: sessionReadingFontSizePoints, weight: .medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }

                            if item.translationLine.isEmpty {
                                Text(item.displayTranslationLine)
                                    .font(.system(size: max(11, sessionReadingFontSizePoints - 2)))
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(item.translationLine)
                                    .font(.system(size: max(11, sessionReadingFontSizePoints - 2)))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if index < viewModel.sessionReadingSequence.count - 1 {
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var hasSelectedStudyMaterialContent: Bool {
        viewModel.studyMaterials.words?.hasContent == true
    }

    @ViewBuilder
    private var studyAssistantBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Перевод слов")
                    .font(.headline)
                Spacer()
                Button(hasSelectedStudyMaterialContent ? "Обновить перевод" : "Перевести слова") {
                    viewModel.retryStudyAssistantDataForSelectedEntry()
                }
                .disabled(viewModel.selectedEntryStudyAssistantStatus == .processing)
            }

            Group {
                if hasSelectedStudyMaterialContent {
                    ScrollView {
                        studyAssistantContent
                    }
                } else {
                    studyAssistantContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background.secondary)
        )
    }

    @ViewBuilder
    private var studyAssistantContent: some View {
        if viewModel.selectedEntryStudyAssistantStatus == .processing {
            centeredContent {
                ContentUnavailableView(
                    "Готовлю перевод слов",
                    systemImage: "books.vertical",
                    description: Text("Запрашиваю слова для текущего текста.")
                )
            }
        } else if hasSelectedStudyMaterialContent {
            wordsView(viewModel.studyMaterials.words)
        } else if viewModel.canRetryStudyAssistantData {
            centeredContent {
                ContentUnavailableView(
                    "Слова не загрузились",
                    systemImage: "arrow.clockwise.circle",
                    description: Text("Можно запросить перевод слов еще раз.")
                )
            }
        } else {
            centeredContent {
                ContentUnavailableView(
                    "Загрузить перевод слов",
                    systemImage: "hand.tap",
                    description: Text("Материал загружается только по запросу.")
                )
            }
        }
    }

    @ViewBuilder
    private func wordsView(_ payload: WordStudyPayload?) -> some View {
        if let payload, !payload.entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(payload.entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(entry.termPinyin)
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                            if !entry.russianPronunciationGuide.isEmpty {
                                Text("(\(entry.russianPronunciationGuide))")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundStyle(.secondary)
                            }
                            Text("-")
                                .font(.system(size: 17, weight: .regular, design: .default))
                            Text(entry.termTranslation)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                        if !entry.characterBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Разбор")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(entry.characterBreakdown.enumerated()), id: \.offset) { _, part in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(part.pinyinText)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .frame(width: 120, alignment: .leading)
                                            .textSelection(.enabled)
                                        Text(part.russianTranslation)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.background)
                    )
                }
            }
        } else {
            ContentUnavailableView(
                "Слова не найдены",
                systemImage: "list.bullet.rectangle",
                description: Text("Для этой записи AI не выделил слов для изучения.")
            )
        }
    }

    @ViewBuilder
    private func formattedTranslationBlock(_ formatted: StructuredFormattedText) -> some View {
        VStack(spacing: 10) {
            if shouldShowCleanedTextAbovePrimary(for: formatted) {
                Text(formatted.cleanedText)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            Text(primaryFormattedLine(formatted))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            Text(formatted.russianTranslation)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background.secondary)
        )
    }

    private func primaryFormattedLine(_ formatted: StructuredFormattedText) -> String {
        if shouldUsePinyinAsPrimary(for: formatted) {
            return formatted.pinyinText.isEmpty ? "—" : formatted.pinyinText
        }
        return formatted.cleanedText
    }

    private func shouldShowCleanedTextAbovePrimary(for formatted: StructuredFormattedText) -> Bool {
        shouldUsePinyinAsPrimary(for: formatted)
    }

    private func shouldUsePinyinAsPrimary(for formatted: StructuredFormattedText) -> Bool {
        if viewModel.currentProfileLearningLanguage == .chinese {
            return true
        }
        return viewModel.currentProfileLearningLanguage == .auto && !formatted.pinyinText.isEmpty
    }

    private func sidebarActionButton(
        systemName: String,
        helpText: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(width: 32, height: 30)
        .help(helpText)
    }

    private func centeredContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PanelGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
                .font(.headline)

            configuration.content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background.secondary)
        )
    }
}

#Preview {
    ContentView(viewModel: AppDependencyContainer.live().makeMainViewModel())
}
