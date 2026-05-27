//
//  MenuBarPanelView.swift
//  llh
//

import SwiftUI

struct MenuBarPanelView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppDisplayStrings.productName)
                .font(.headline)

            Text(viewModel.capture.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Button("Захват") {
                    viewModel.capture.triggerCapture()
                }
                .disabled(viewModel.capture.isProcessing)

                Button("Открыть окно") {
                    openWindow(id: "main-window")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
