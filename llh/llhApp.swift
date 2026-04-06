//
//  llhApp.swift
//  llh
//
//  Created by itsme on 06.04.2026.
//

import SwiftUI

@main
struct llhApp: App {
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup(id: "main-window") {
            ContentView(viewModel: viewModel)
        }

        MenuBarExtra("Language Learning Helper", systemImage: "text.viewfinder") {
            MenuBarPanelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
