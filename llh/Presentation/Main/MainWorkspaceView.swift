//
//  MainWorkspaceView.swift
//  llh
//

import SwiftUI

struct MainWorkspaceView: View {
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var editor: EditorViewModel
    @ObservedObject var study: StudyViewModel
    @ObservedObject var capture: CaptureViewModel

    var defaultNewProfileLearningLanguage: LearningLanguage
    var isTranslationsSidebarCollapsed: Bool

    private let columnSpacing: CGFloat = 12
    private let detailMinimumWidth: CGFloat = 420
    private let sidebarMinimumWidth: CGFloat = 280

    var body: some View {
        GeometryReader { geometry in
            let spacing = isTranslationsSidebarCollapsed ? 0 : columnSpacing
            let availableWidth = max(geometry.size.width - spacing, 0)
            let sidebarWidth = min(
                max(sidebarMinimumWidth, availableWidth * 0.25),
                max(sidebarMinimumWidth, availableWidth - detailMinimumWidth)
            )

            HStack(alignment: .top, spacing: spacing) {
                if !isTranslationsSidebarCollapsed {
                    GroupBox("Переводы") {
                        HistoryView(
                            viewModel: history,
                            defaultNewProfileLearningLanguage: defaultNewProfileLearningLanguage
                        )
                    }
                    .groupBoxStyle(PanelGroupBoxStyle())
                    .frame(
                        minWidth: sidebarWidth,
                        idealWidth: sidebarWidth,
                        maxWidth: sidebarWidth,
                        maxHeight: .infinity
                    )
                }

                GroupBox {
                    TranslationDetailPanelView(
                        history: history,
                        editor: editor,
                        study: study
                    )
                } label: {
                    Text(history.showsSessionReadingOverview ? "Вся сессия" : "Перевод")
                }
                .groupBoxStyle(PanelGroupBoxStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            }
        }
        .frame(minHeight: 320)
        .captureProcessingOverlay(isProcessing: capture.isProcessing)
    }
}
