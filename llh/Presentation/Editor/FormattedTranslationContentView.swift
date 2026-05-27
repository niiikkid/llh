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
        ScrollView {
            if let formatted = editor.formattedRecognizedText, formatted.hasContent {
                VStack(spacing: 12) {
                    FormattedTranslationBlockView(
                        formatted: formatted,
                        learningLanguage: history.currentProfileLearningLanguage
                    )
                    if history.currentProfileSupportsWordStudy {
                        StudyAssistantView(study: study)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            } else {
                CenteredContentContainer {
                    ContentUnavailableView(
                        "Форматированного текста пока нет",
                        systemImage: "doc.text",
                        description: Text("Сырой текст сохранён, форматирование недоступно для этой записи.")
                    )
                }
            }
        }
    }
}
