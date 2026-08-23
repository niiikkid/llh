//
//  StudyAssistantView.swift
//  llh
//

import SwiftUI

struct StudyAssistantView: View {
    @ObservedObject var study: StudyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Перевод слов")
                    .font(.headline)
                Spacer()
                Button(study.wordsRetryButtonTitle) {
                    study.retryStudyAssistantDataForSelectedEntry()
                }
                .disabled(study.selectedEntryWordsStatus == .processing)
            }

            Group {
                if study.hasVisibleWordsContent {
                    ScrollView {
                        wordsBody
                    }
                } else {
                    wordsBody
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
    private var wordsBody: some View {
        if study.selectedEntryWordsStatus == .processing {
            StudyWordsLoadingView(
                title: "Готовлю перевод слов",
                subtitle: "Запрашиваю слова для текущего текста."
            )
        } else if study.hasWordsContent {
            WordStudyEntriesView(payload: study.studyMaterials.words)
        } else if study.canRetryWordsStudy {
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
                    description: Text(wordsEmptyStateDescription)
                )
            }
        }
    }

    private var wordsEmptyStateDescription: String {
        if study.sessionAutomaticallyLoadsWords {
            return "Перевод слов запустится автоматически после форматирования, если включено в настройках сессии."
        }
        return "Материал загружается по кнопке выше."
    }
}

private struct StudyWordsLoadingView: View {
    let title: String
    let subtitle: String

    var body: some View {
        CenteredContentContainer {
            VStack(spacing: 12) {
                ProgressView()
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
