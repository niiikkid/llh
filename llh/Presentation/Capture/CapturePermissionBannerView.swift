//
//  CapturePermissionBannerView.swift
//  llh
//

import SwiftUI

struct CapturePermissionBannerView: View {
    @ObservedObject var viewModel: CaptureViewModel

    var body: some View {
        GroupBox("Нужно разрешение Screen Recording") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Откройте System Settings -> Privacy & Security -> Screen Recording и включите доступ для приложения.")
                HStack {
                    Button("Запросить доступ") {
                        viewModel.requestScreenRecordingAccess()
                    }
                    .disabled(viewModel.isProcessing)
                    Button("Open System Settings") {
                        viewModel.openSystemSettings()
                    }
                    Button("Проверить снова") {
                        viewModel.refreshPermissionState()
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
            .font(.callout)
        }
    }
}
