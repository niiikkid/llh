//
//  StudyAssistantView.swift
//  llh
//

import SwiftUI

struct StudyAssistantView: View {
    @ObservedObject var study: StudyViewModel
    @ObservedObject var history: HistoryViewModel

    private var hasSelectedStudyMaterialContent: Bool {
        study.studyMaterials.words?.hasContent == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Перевод слов")
                    .font(.headline)
                Spacer()
                Button(hasSelectedStudyMaterialContent ? "Обновить перевод" : "Перевести слова") {
                    study.retryStudyAssistantDataForSelectedEntry()
                }
                .disabled(study.selectedEntryStudyAssistantStatus == .processing)
            }

            Group {
                if hasSelectedStudyMaterialContent {
                    ScrollView {
                        studyAssistantBody
                    }
                } else {
                    studyAssistantBody
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
    private var studyAssistantBody: some View {
        if study.selectedEntryStudyAssistantStatus == .processing {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Готовлю перевод слов",
                    systemImage: "books.vertical",
                    description: Text("Запрашиваю слова для текущего текста.")
                )
            }
        } else if hasSelectedStudyMaterialContent {
            WordStudyEntriesView(payload: study.studyMaterials.words)
        } else if study.canRetryStudyAssistantData {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Слова не загрузились",
                    systemImage: "arrow.clockwise.circle",
                    description: Text("Можно запросить перевод слов еще раз.")
                )
            }
        } else {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Загрузить перевод слов",
                    systemImage: "hand.tap",
                    description: Text("Материал загружается только по запросу.")
                )
            }
        }
    }
}
