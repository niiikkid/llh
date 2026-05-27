//
//  CapturePermissionBannerView.swift
//  llh
//

import SwiftUI

struct CapturePermissionBannerView: View {
    @ObservedObject var viewModel: CaptureViewModel

    var body: some View {
        GroupBox("Нужно разрешение на запись экрана") {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Откройте «Системные настройки» → «Конфиденциальность и безопасность» → «Запись экрана» и включите доступ для приложения."
                )
                HStack {
                    Button("Запросить доступ") {
                        viewModel.requestScreenRecordingAccess()
                    }
                    .disabled(viewModel.isProcessing)
                    Button("Системные настройки") {
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
