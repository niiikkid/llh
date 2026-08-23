//
//  CompactOverlayView.swift
//  llh
//

import SwiftUI

enum CompactOverlayContent: Equatable {
    case loading(String)
    case translation(formattedText: StructuredFormattedText, wordsPhase: CompactOverlayWordsPhase?)
    case message(title: String, subtitle: String?)

    var contentKind: CompactOverlayContentKind {
        switch self {
        case .loading: .loading
        case .translation: .translation
        case .message: .message
        }
    }
}

enum CompactOverlayContentKind {
    case loading
    case translation
    case message
}

enum CompactOverlayLayout {
    static let translationCardWidth: CGFloat = 360
    static let chatCardWidth: CGFloat = 300
    static let cardSpacing: CGFloat = 10
    static let maxWidthWithoutChat: CGFloat = 460
    static let chatMinimumHeight: CGFloat = 160
    static let screenMargin: CGFloat = 8

    /// Places the chat window to the right of the translation overlay, or to the left if it does not fit.
    static func chatPanelOrigin(
        translationFrame: CGRect,
        chatSize: CGSize,
        visibleScreen: CGRect
    ) -> CGPoint {
        let preferredX = translationFrame.maxX + cardSpacing
        let fitsOnRight = preferredX + chatSize.width <= visibleScreen.maxX - screenMargin
        let x = fitsOnRight
            ? preferredX
            : translationFrame.minX - cardSpacing - chatSize.width
        let clampedX = min(
            max(x, visibleScreen.minX + screenMargin),
            visibleScreen.maxX - chatSize.width - screenMargin
        )
        let clampedY = min(
            max(translationFrame.minY, visibleScreen.minY + screenMargin),
            visibleScreen.maxY - chatSize.height - screenMargin
        )
        return CGPoint(x: clampedX, y: clampedY)
    }
}

struct CompactOverlayHost: View {
    let content: CompactOverlayContent
    let chatViewModel: CompactOverlayChatViewModel?
    let onClose: () -> Void

    var contentKind: CompactOverlayContentKind {
        content.contentKind
    }

    var body: some View {
        if let chatViewModel {
            CompactOverlayObservedHost(content: content, chatViewModel: chatViewModel, onClose: onClose)
        } else {
            CompactOverlayView(content: content, chatViewModel: nil, onClose: onClose)
        }
    }
}

private struct CompactOverlayObservedHost: View {
    let content: CompactOverlayContent
    @ObservedObject var chatViewModel: CompactOverlayChatViewModel
    let onClose: () -> Void

    var body: some View {
        CompactOverlayView(content: content, chatViewModel: chatViewModel, onClose: onClose)
    }
}

struct CompactOverlayView: View {
    let content: CompactOverlayContent
    let chatViewModel: CompactOverlayChatViewModel?
    let onClose: () -> Void

    var contentKind: CompactOverlayContentKind {
        content.contentKind
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                switch content {
                case .loading(let text):
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                case .translation(let formattedText, let wordsPhase):
                    CompactOverlayTranslationSectionView(
                        formattedText: formattedText,
                        wordsPhase: wordsPhase,
                        chatViewModel: chatViewModel
                    )

                case .message(let title, let subtitle):
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Закрыть (Escape)")
        }
        .frame(width: CompactOverlayLayout.translationCardWidth)
        .background(CompactOverlayCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

private struct CompactOverlayTranslationSectionView: View {
    let formattedText: StructuredFormattedText
    let wordsPhase: CompactOverlayWordsPhase?
    let chatViewModel: CompactOverlayChatViewModel?

    var body: some View {
        let primaryText = formattedText.overlayPrimaryText
        let secondaryText = formattedText.russianTranslation

        VStack(spacing: 10) {
            if !primaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(primaryText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }

            Text(secondaryText)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            if let chatViewModel {
                CompactOverlayVoiceButton(viewModel: chatViewModel)

                if let statusMessage = chatViewModel.statusMessage, !chatViewModel.isSidePanelVisible {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }

            if let wordsPhase {
                CompactOverlayWordsSectionView(phase: wordsPhase)
            }
        }
    }
}

private struct CompactOverlayVoiceButton: View {
    @ObservedObject var viewModel: CompactOverlayChatViewModel
    @State private var isPulsing = false

    var body: some View {
        Button(action: viewModel.handleMicTapped) {
            ZStack {
                if viewModel.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.55), lineWidth: 2)
                        .frame(width: 34, height: 34)
                        .scaleEffect(isPulsing ? 1.55 : 1)
                        .opacity(isPulsing ? 0 : 0.9)
                    Circle()
                        .fill(Color.red.opacity(0.16))
                        .frame(width: 34, height: 34)
                }

                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(viewModel.isRecording ? Color.red : Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.isRecording)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: viewModel.isTranscribing)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isTranscribing)
        .help(helpText)
        .onChange(of: viewModel.isRecording) { _, isRecording in
            if isRecording {
                isPulsing = false
                withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }

    private var helpText: String {
        if viewModel.isRecording {
            return CompactOverlayChatStrings.stopRecording
        }
        if viewModel.isTranscribing {
            return CompactOverlayChatStrings.transcribing
        }
        return CompactOverlayChatStrings.askByVoice
    }
}

private struct CompactOverlayWordsSectionView: View {
    let phase: CompactOverlayWordsPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 2)

            switch phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Перевожу слова…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .ready(let payload):
                Text("Перевод слов")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(payload.entries.enumerated()), id: \.offset) { _, entry in
                            CompactOverlayWordEntryRowView(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 180)

            case .failed:
                Text("Не удалось перевести слова.")
                    .font(.caption)
                    .foregroundStyle(.orange)

            case .unavailable:
                Text("Перевод слов недоступен для этой сессии.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactOverlayWordEntryRowView: View {
    let entry: WordStudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.termPinyin)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if !entry.russianPronunciationGuide.isEmpty {
                    Text("(\(entry.russianPronunciationGuide))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("—")
                    .foregroundStyle(.secondary)
                Text(entry.termTranslation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CompactOverlayCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.24))
            )
    }
}
