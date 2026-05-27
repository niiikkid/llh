//
//  HistoryView.swift
//  llh
//

import SwiftUI

/// Translation list for the active session (sidebar in workspace).
struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    var defaultNewProfileLearningLanguage: LearningLanguage

    @State private var newProfileName = ""
    @State private var newProfileLearningLanguage: LearningLanguage = .english
    @State private var newProfileAutomaticallyLoadWords = false
    @State private var newProfileAutomaticallyLoadGrammar = false
    @State private var newProfileShowWordsInCompactOverlay = false
    @State private var isCreateProfilePresented = false
    @State private var isDeleteProfileConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sessionPickerRow

            HStack(spacing: 8) {
                Text("Язык сессии:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                SessionLanguageBadge(language: viewModel.currentProfileLearningLanguage)
                Spacer(minLength: 0)
            }

            if viewModel.currentProfileLearningLanguage == .auto {
                Text("Для этой сессии язык определяется автоматически, отображается только перевод.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.selectedProfileID != nil {
                sessionAutomationSection
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
                        Spacer(minLength: 0)
                    }

                    List(
                        viewModel.history,
                        selection: Binding(
                            get: { viewModel.selectedEntryID },
                            set: { viewModel.selectEntry($0) }
                        )
                    ) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                item.sessionListTitleLine(
                                    learningLanguage: viewModel.currentProfileLearningLanguage
                                )
                            )
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
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
        .sheet(isPresented: $isCreateProfilePresented) {
            createProfileSheet
        }
        .alert("Удалить сессию?", isPresented: $isDeleteProfileConfirmationPresented) {
            Button("Удалить", role: .destructive) {
                viewModel.deleteSelectedProfile()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(
                "Сессия «\(viewModel.selectedProfileDisplayName)» будет удалена вместе со всеми переводами внутри неё."
            )
        }
    }

    private var sessionPickerRow: some View {
        HStack(spacing: 8) {
            Picker(
                "Сессия",
                selection: Binding(
                    get: { viewModel.selectedProfileID },
                    set: { viewModel.selectProfile($0) }
                )
            ) {
                ForEach(viewModel.profiles) { profile in
                    Text(profile.displayName).tag(Optional(profile.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

            sidebarActionButton(systemName: "plus", helpText: "Создать сессию") {
                newProfileName = ""
                newProfileLearningLanguage = defaultNewProfileLearningLanguage
                newProfileAutomaticallyLoadWords = false
                newProfileAutomaticallyLoadGrammar = false
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
    }

    private var sessionAutomationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("После форматирования")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            SessionAutomationTogglesView(
                loadWords: automationLoadWordsBinding,
                loadGrammar: automationLoadGrammarBinding,
                showWordsInCompactOverlay: showWordsInCompactOverlayBinding
            )
            .font(.caption)
        }
    }

    private var automationLoadWordsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.activeProfile?.automaticallyLoadWords ?? false },
            set: { newValue in
                guard let profileID = viewModel.selectedProfileID else { return }
                viewModel.updateSessionAutomation(
                    profileID: profileID,
                    automaticallyLoadWords: newValue,
                    automaticallyLoadGrammar: viewModel.activeProfile?.automaticallyLoadGrammar ?? false,
                    showWordsInCompactOverlay: viewModel.activeProfile?.showWordsInCompactOverlay ?? false
                )
            }
        )
    }

    private var automationLoadGrammarBinding: Binding<Bool> {
        Binding(
            get: { viewModel.activeProfile?.automaticallyLoadGrammar ?? false },
            set: { newValue in
                guard let profileID = viewModel.selectedProfileID else { return }
                viewModel.updateSessionAutomation(
                    profileID: profileID,
                    automaticallyLoadWords: viewModel.activeProfile?.automaticallyLoadWords ?? false,
                    automaticallyLoadGrammar: newValue,
                    showWordsInCompactOverlay: viewModel.activeProfile?.showWordsInCompactOverlay ?? false
                )
            }
        )
    }

    private var showWordsInCompactOverlayBinding: Binding<Bool> {
        Binding(
            get: { viewModel.activeProfile?.showWordsInCompactOverlay ?? false },
            set: { newValue in
                guard let profileID = viewModel.selectedProfileID else { return }
                viewModel.updateSessionAutomation(
                    profileID: profileID,
                    automaticallyLoadWords: viewModel.activeProfile?.automaticallyLoadWords ?? false,
                    automaticallyLoadGrammar: viewModel.activeProfile?.automaticallyLoadGrammar ?? false,
                    showWordsInCompactOverlay: newValue
                )
            }
        )
    }

    private var createProfileSheet: some View {
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
            Text("Язык сессии нельзя изменить после создания.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SessionAutomationTogglesView(
                loadWords: $newProfileAutomaticallyLoadWords,
                loadGrammar: $newProfileAutomaticallyLoadGrammar,
                showWordsInCompactOverlay: $newProfileShowWordsInCompactOverlay
            )
            HStack {
                Spacer()
                Button("Отмена") {
                    isCreateProfilePresented = false
                }
                Button("Создать") {
                    viewModel.createProfile(
                        named: newProfileName,
                        learningLanguage: newProfileLearningLanguage,
                        automaticallyLoadWords: newProfileAutomaticallyLoadWords,
                        automaticallyLoadGrammar: newProfileAutomaticallyLoadGrammar,
                        showWordsInCompactOverlay: newProfileShowWordsInCompactOverlay
                    )
                    isCreateProfilePresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 400)
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
}
