//
//  HistoryView.swift
//  llh
//

import SwiftUI

/// Translation list for the active session (sidebar in workspace).
struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(viewModel.selectedProfileDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text("Язык сессии:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                SessionLanguageBadge(language: viewModel.currentProfileLearningLanguage)
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
    }
}
