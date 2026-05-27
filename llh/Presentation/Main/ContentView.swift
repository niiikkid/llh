//
//  ContentView.swift
//  llh
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var isTranslationsSidebarCollapsed = false
    @State private var route: AppMainRoute = .workspace
    @State private var routeBeforeSettings: AppMainRoute = .workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MainChromeView(
                settings: viewModel.settings,
                route: $route,
                isTranslationsSidebarCollapsed: $isTranslationsSidebarCollapsed,
                canReturnToWorkspace: viewModel.history.selectedProfileID != nil,
                onNavigate: navigate(to:)
            )

            if viewModel.capture.showPermissionHelp, route == .workspace {
                CapturePermissionBannerView(viewModel: viewModel.capture)
            }

            routeContent
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 500)
        .background(MainWindowIdentityView())
    }

    private func navigate(to destination: AppMainRoute) {
        if destination == .settings, route != .settings {
            routeBeforeSettings = route
        }
        if destination == .workspace, route == .settings {
            route = routeBeforeSettings
            return
        }
        route = destination
    }

    @ViewBuilder
    private var routeContent: some View {
        switch route {
        case .sessions:
            SessionsListView(
                viewModel: viewModel.history,
                defaultNewProfileLearningLanguage: viewModel.settings.defaultNewProfileLearningLanguage,
                onOpenSession: { _ in
                    route = .workspace
                }
            )
        case .workspace:
            if viewModel.history.selectedProfileID == nil {
                SessionsListView(
                    viewModel: viewModel.history,
                    defaultNewProfileLearningLanguage: viewModel.settings.defaultNewProfileLearningLanguage,
                    onOpenSession: { _ in
                        route = .workspace
                    }
                )
            } else {
                MainWorkspaceView(
                    history: viewModel.history,
                    editor: viewModel.editor,
                    study: viewModel.study,
                    capture: viewModel.capture,
                    isTranslationsSidebarCollapsed: isTranslationsSidebarCollapsed
                )
            }
        case .settings:
            SettingsView(viewModel: viewModel.settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview {
    ContentView(viewModel: AppDependencyContainer.live().makeMainViewModel())
}
