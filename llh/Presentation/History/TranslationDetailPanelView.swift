//
//  TranslationDetailPanelView.swift
//  llh
//

import SwiftUI

struct TranslationDetailPanelView: View {
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var editor: EditorViewModel
    @ObservedObject var study: StudyViewModel

    var body: some View {
        Group {
            if history.showsSessionReadingOverview {
                if history.history.isEmpty {
                    CenteredContentContainer {
                        ContentUnavailableView(
                            "Пока пусто",
                            systemImage: "doc.plaintext",
                            description: Text("В этой сессии ещё нет переводов.")
                        )
                    }
                } else {
                    SessionReadingOverviewView(history: history)
                }
            } else if history.selectedEntryID == nil {
                CenteredContentContainer {
                    ContentUnavailableView(
                        "Выберите перевод",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Слева выберите перевод из сессии, чтобы открыть полный текст.")
                    )
                }
            } else {
                TranslationEditorView(
                    editor: editor,
                    history: history,
                    study: study
                )
            }
        }
    }
}
