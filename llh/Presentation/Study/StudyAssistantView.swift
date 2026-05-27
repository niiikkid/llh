//
//  StudyAssistantView.swift
//  llh
//

import SwiftUI

struct StudyAssistantView: View {
    @ObservedObject var study: StudyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Учебные материалы", selection: $study.selectedLearningTab) {
                ForEach(StudyLearningTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text(study.selectedLearningTab.title)
                    .font(.headline)
                Spacer()
                Button(study.activeTabRetryButtonTitle) {
                    study.retryStudyAssistantDataForSelectedEntry()
                }
                .disabled(study.activeLearningTabStatus == .processing)
            }

            Group {
                if study.hasActiveTabContent {
                    ScrollView {
                        activeTabBody
                    }
                } else {
                    activeTabBody
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
    private var activeTabBody: some View {
        switch study.selectedLearningTab {
        case .words:
            wordsTabBody
        case .grammar:
            grammarTabBody
        }
    }

    @ViewBuilder
    private var wordsTabBody: some View {
        if study.selectedEntryWordsStatus == .processing {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Готовлю перевод слов",
                    systemImage: "books.vertical",
                    description: Text("Запрашиваю слова для текущего текста.")
                )
            }
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

    @ViewBuilder
    private var grammarTabBody: some View {
        if study.selectedEntryGrammarStatus == .processing {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Готовлю грамматику",
                    systemImage: "text.book.closed",
                    description: Text("Разбираю, как связаны части предложения.")
                )
            }
        } else if study.hasGrammarContent {
            GrammarExplanationView(payload: study.studyMaterials.grammar)
        } else if study.canRetryGrammarStudy {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Грамматика не загрузилась",
                    systemImage: "arrow.clockwise.circle",
                    description: Text("Можно запросить объяснение еще раз.")
                )
            }
        } else {
            CenteredContentContainer {
                ContentUnavailableView(
                    "Загрузить грамматику",
                    systemImage: "hand.tap",
                    description: Text(grammarEmptyStateDescription)
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

    private var grammarEmptyStateDescription: String {
        if study.sessionAutomaticallyLoadsGrammar {
            return "Грамматика запустится автоматически после форматирования, если включено в настройках сессии."
        }
        return "Объяснение загружается по кнопке выше."
    }
}
