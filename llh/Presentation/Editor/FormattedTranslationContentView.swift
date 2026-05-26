//
//  FormattedTranslationContentView.swift
//  llh
//

import SwiftUI

struct FormattedTranslationContentView: View {
    @ObservedObject var editor: EditorViewModel
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var study: StudyViewModel

    var body: some View {
        Group {
            if let formatted = editor.formattedRecognizedText, formatted.hasContent {
                VStack(spacing: 12) {
                    FormattedTranslationBlockView(
                        formatted: formatted,
                        learningLanguage: history.currentProfileLearningLanguage
                    )
                    if history.currentProfileSupportsWordStudy {
                        StudyAssistantView(study: study, history: history)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if editor.isFormattingRecognizedText || editor.selectedEntryFormattingStatus == .processing {
                CenteredContentContainer {
                    ContentUnavailableView(
                        "Форматирую текст",
                        systemImage: "wand.and.stars",
                        description: Text("Подождите, запрос в OpenAI выполняется.")
                    )
                }
            } else if editor.canRetryFormatting {
                CenteredContentContainer {
                    VStack(alignment: .center, spacing: 10) {
                        ContentUnavailableView(
                            "Форматирование не удалось",
                            systemImage: "exclamationmark.arrow.circlepath",
                            description: Text("Можно отправить запрос в OpenAI повторно.")
                        )
                        Button("Попробовать еще раз") {
                            editor.retryFormattingForSelectedEntry()
                        }
                        .disabled(editor.isFormattingRecognizedText)
                    }
                }
            } else {
                CenteredContentContainer {
                    ContentUnavailableView(
                        "Форматированного текста пока нет",
                        systemImage: "doc.text",
                        description: Text("Сырой текст сохранен, форматирование недоступно для этой записи.")
                    )
                }
            }
        }
    }
}
