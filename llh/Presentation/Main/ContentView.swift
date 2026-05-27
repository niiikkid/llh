//
//  ContentView.swift
//  llh
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedTextTab: TranslationTextTab = .formatted
    @State private var isSessionsPanelCollapsed = false
    @State private var isSettingsPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MainChromeView(
                settings: viewModel.settings,
                isSessionsPanelCollapsed: $isSessionsPanelCollapsed,
                isSettingsPresented: $isSettingsPresented
            )

            if viewModel.capture.showPermissionHelp {
                CapturePermissionBannerView(viewModel: viewModel.capture)
            }

            MainWorkspaceView(
                history: viewModel.history,
                editor: viewModel.editor,
                study: viewModel.study,
                capture: viewModel.capture,
                defaultNewProfileLearningLanguage: viewModel.settings.defaultNewProfileLearningLanguage,
                isSessionsPanelCollapsed: isSessionsPanelCollapsed,
                selectedTextTab: $selectedTextTab
            )
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 500)
        .background(MainWindowIdentityView())
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel.settings)
        }
    }
}

#Preview {
    ContentView(viewModel: AppDependencyContainer.live().makeMainViewModel())
}
