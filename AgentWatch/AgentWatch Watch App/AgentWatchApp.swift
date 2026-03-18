// AgentWatchApp.swift
// Entry point for the Agent Watch watchOS application.
// PLATFORM NOTE: This file requires Xcode 15+ on macOS to build and sign.
// Linux CI tests cover the shared AgentWatchCore package only.

import SwiftUI

@main
struct AgentWatchApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
