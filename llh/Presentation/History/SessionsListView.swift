//
//  SessionsListView.swift
//  llh
//

import SwiftUI

struct SessionsListView: View {
    @ObservedObject var viewModel: HistoryViewModel
    var defaultNewProfileLearningLanguage: LearningLanguage
    var onOpenSession: (LearningProfile.ID) -> Void

    @State private var newProfileName = ""
    @State private var newProfileLearningLanguage: LearningLanguage = .english
    @State private var newProfileAutomaticallyLoadWords = false
    @State private var newProfileAutomaticallyLoadGrammar = false
    @State private var isCreateProfilePresented = false
    @State private var profilePendingDelete: LearningProfile?
    @State private var profilePendingRename: LearningProfile?
    @State private var profilePendingAutomation: LearningProfile?
    @State private var renameProfileName = ""
    @State private var automationLoadWords = false
    @State private var automationLoadGrammar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    newProfileName = ""
                    newProfileLearningLanguage = defaultNewProfileLearningLanguage
                    newProfileAutomaticallyLoadWords = false
                    newProfileAutomaticallyLoadGrammar = false
                    isCreateProfilePresented = true
                } label: {
                    Label("Создать сессию", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.profiles.isEmpty {
                ContentUnavailableView(
                    "Нет сессий",
                    systemImage: "tray",
                    description: Text("Создайте сессию, чтобы начать сохранять переводы.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.profiles) { profile in
                    sessionRow(profile)
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $isCreateProfilePresented) {
            createProfileSheet
        }
        .sheet(item: $profilePendingRename) { profile in
            renameProfileSheet(profile)
        }
        .sheet(item: $profilePendingAutomation) { profile in
            sessionAutomationSheet(profile)
        }
        .alert(
            "Удалить сессию?",
            isPresented: Binding(
                get: { profilePendingDelete != nil },
                set: { if !$0 { profilePendingDelete = nil } }
            )
        ) {
            Button("Удалить", role: .destructive) {
                if let profile = profilePendingDelete {
                    viewModel.deleteProfile(id: profile.id)
                }
                profilePendingDelete = nil
            }
            Button("Отмена", role: .cancel) {
                profilePendingDelete = nil
            }
        } message: {
            if let profile = profilePendingDelete {
                Text(
                    "Сессия «\(profile.displayName)» будет удалена вместе со всеми переводами внутри неё."
                )
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ profile: LearningProfile) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.displayName)
                    .font(.headline)
                HStack(spacing: 8) {
                    SessionLanguageBadge(language: profile.learningLanguage)
                    Text(translationCountLabel(for: profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if profile.learningLanguage == .auto {
                    Text("Язык определяется автоматически и не меняется после создания сессии.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if profile.automaticallyLoadWords || profile.automaticallyLoadGrammar {
                    Text(sessionAutomationSummary(for: profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Button("Открыть") {
                    viewModel.selectProfile(profile.id)
                    onOpenSession(profile.id)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    renameProfileName = profile.name
                    profilePendingRename = profile
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Переименовать сессию")

                Button {
                    automationLoadWords = profile.automaticallyLoadWords
                    automationLoadGrammar = profile.automaticallyLoadGrammar
                    profilePendingAutomation = profile
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Автозагрузка учебных материалов")

                Button(role: .destructive) {
                    profilePendingDelete = profile
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Удалить сессию")
                .disabled(!viewModel.canDeleteProfile(id: profile.id))
            }
        }
        .padding(.vertical, 6)
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
                loadGrammar: $newProfileAutomaticallyLoadGrammar
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
                        automaticallyLoadGrammar: newProfileAutomaticallyLoadGrammar
                    )
                    isCreateProfilePresented = false
                    if let createdID = viewModel.selectedProfileID {
                        onOpenSession(createdID)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 400)
    }

    private func renameProfileSheet(_ profile: LearningProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Переименовать сессию")
                .font(.headline)
            TextField("Название сессии", text: $renameProfileName)
            HStack {
                Spacer()
                Button("Отмена") {
                    profilePendingRename = nil
                }
                Button("Сохранить") {
                    viewModel.renameProfile(id: profile.id, named: renameProfileName)
                    profilePendingRename = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func sessionAutomationSheet(_ profile: LearningProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Автозагрузка для «\(profile.displayName)»")
                .font(.headline)
            Text("После успешного форматирования перевода сессия может автоматически запросить учебные материалы.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SessionAutomationTogglesView(
                loadWords: $automationLoadWords,
                loadGrammar: $automationLoadGrammar
            )
            HStack {
                Spacer()
                Button("Отмена") {
                    profilePendingAutomation = nil
                }
                Button("Сохранить") {
                    viewModel.updateSessionAutomation(
                        profileID: profile.id,
                        automaticallyLoadWords: automationLoadWords,
                        automaticallyLoadGrammar: automationLoadGrammar
                    )
                    profilePendingAutomation = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func sessionAutomationSummary(for profile: LearningProfile) -> String {
        switch (profile.automaticallyLoadWords, profile.automaticallyLoadGrammar) {
        case (true, true):
            return "Авто: слова и грамматика после перевода"
        case (true, false):
            return "Авто: перевод слов после перевода"
        case (false, true):
            return "Авто: грамматика после перевода"
        case (false, false):
            return ""
        }
    }

    private func translationCountLabel(for profile: LearningProfile) -> String {
        let count = profile.history.count
        switch count {
        case 0:
            return "Нет переводов"
        case 1:
            return "1 перевод"
        case 2...4:
            return "\(count) перевода"
        default:
            return "\(count) переводов"
        }
    }
}
