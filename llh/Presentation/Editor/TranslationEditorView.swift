//
//  TranslationEditorView.swift
//  llh
//

import SwiftUI

struct TranslationEditorView: View {
    @ObservedObject var editor: EditorViewModel
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var study: StudyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            translationContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                if editor.showsFormattingRetryAction {
                    Button {
                        editor.retryFormattingForSelectedEntry()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Повторить форматирование")
                    .disabled(editor.isFormattingRecognizedText)
                }

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

    @ViewBuilder
    private var translationContent: some View {
        switch editor.translationResultPresentation {
        case .loading:
            rawTranslationEditor(readOnly: true)
                .overlay(alignment: .top) {
                    formattingProgressBanner
                        .padding(.top, 8)
                }
        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                formattingFailureBanner
                rawTranslationEditor(readOnly: false)
            }
        case .rawOnly:
            rawTranslationEditor(readOnly: false)
        case .formatted:
            FormattedTranslationContentView(
                editor: editor,
                history: history,
                study: study
            )
        }
    }

    private var formattingProgressBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Форматирую текст…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var formattingFailureBanner: some View {
        Label {
            Text(editor.formattingFailureMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func rawTranslationEditor(readOnly: Bool) -> some View {
        TextEditor(
            text: Binding(
                get: { editor.recognizedText },
                set: { editor.updateSelectedText($0) }
            )
        )
        .font(.system(.body, design: .monospaced))
        .disabled(readOnly)
    }
}
