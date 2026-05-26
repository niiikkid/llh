//
//  TranslationEditorView.swift
//  llh
//

import SwiftUI

struct TranslationEditorView: View {
    @ObservedObject var editor: EditorViewModel
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var study: StudyViewModel

    @Binding var selectedTextTab: TranslationTextTab

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $selectedTextTab) {
                Text("Сырой текст").tag(TranslationTextTab.raw)
                Text("Форматированный").tag(TranslationTextTab.formatted)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                if selectedTextTab == .raw {
                    TextEditor(
                        text: Binding(
                            get: { editor.recognizedText },
                            set: { editor.updateSelectedText($0) }
                        )
                    )
                    .font(.system(.body, design: .monospaced))
                } else {
                    FormattedTranslationContentView(
                        editor: editor,
                        history: history,
                        study: study
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                Spacer()
                Button(role: .destructive) {
                    history.deleteSelectedEntry()
                } label: {
                    Label("Удалить перевод", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!history.canDeleteSelectedEntry)
            }
        }
    }
}

enum TranslationTextTab: String, Hashable {
    case raw
    case formatted
}
