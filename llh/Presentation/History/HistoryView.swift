//
//  HistoryView.swift
//  llh
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    var defaultNewProfileLearningLanguage: LearningLanguage

    @State private var newProfileName = ""
    @State private var newProfileLearningLanguage: LearningLanguage = .english
    @State private var isCreateProfilePresented = false
    @State private var isDeleteProfileConfirmationPresented = false

    var body: some View {
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
                    newProfileLearningLanguage = defaultNewProfileLearningLanguage
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
        .alert("Удалить сессию?", isPresented: $isDeleteProfileConfirmationPresented) {
            Button("Удалить", role: .destructive) {
                viewModel.deleteSelectedProfile()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сессия \"\(viewModel.selectedProfileName)\" будет удалена вместе со всеми переводами внутри нее.")
        }
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
