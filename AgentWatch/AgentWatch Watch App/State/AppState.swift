// AppState.swift
// Central ObservableObject. Coordinates SpeechRecorder, VPSClient, SpeechSynthesizer,
// and ConversationStore. All mutations happen on MainActor.

import Foundation
import SwiftUI

enum AppPhase: Equatable {
    case idle
    case listening
    case thinking
    case responding
    case error(String)

    static func == (lhs: AppPhase, rhs: AppPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.listening, .listening), (.thinking, .thinking), (.responding, .responding):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .idle
    @Published var partialTranscript: String = ""
    @Published var responseBuffer: String = ""

    let conversationStore = ConversationStore()

    private let vpsClient = VPSClient()
    private var currentSessionID: String = ""
    private var currentQuery: String = ""
    private var vpsURL: String = ""
    private var authToken: String = ""

    init() {
        loadSettings()
        setupVPSCallbacks()
    }

    // MARK: - Settings

    func loadSettings() {
        vpsURL = UserDefaults.standard.string(forKey: "vps_url") ?? ""
        authToken = KeychainHelper.load(key: "auth_token") ?? ""
    }

    func reloadSettings() { loadSettings() }

    // MARK: - Voice Flow

    func startListening() {
        phase = .listening
        partialTranscript = ""
        // SpeechRecorder is owned by ContentView and drives partialTranscript updates
        // via the environment. This method signals the state machine.
    }

    func updatePartialTranscript(_ text: String) {
        partialTranscript = text
    }

    func submitTranscript() {
        let text = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { phase = .idle; return }
        currentQuery = text
        currentSessionID = UUID().uuidString
        responseBuffer = ""
        phase = .thinking
        sendToVPS(text: text)
    }

    func cancel() {
        Task {
            try? await vpsClient.sendCancel(sessionID: currentSessionID)
        }
        phase = .idle
        responseBuffer = ""
    }

    func reset() {
        phase = .idle
        responseBuffer = ""
        partialTranscript = ""
    }

    func setError(_ message: String) {
        phase = .error(message)
    }

    // MARK: - Network

    private func setupVPSCallbacks() {
        vpsClient.onChunk = { [weak self] text, _ in
            guard let self else { return }
            self.responseBuffer += text
            if self.phase != .responding { self.phase = .responding }
        }
        vpsClient.onDone = { [weak self] _ in
            guard let self else { return }
            self.conversationStore.append(
                query: self.currentQuery,
                response: self.responseBuffer
            )
            // Keep .responding so user reads; tap to dismiss
        }
        vpsClient.onError = { [weak self] message in
            self?.phase = .error(message)
        }
    }

    private func sendToVPS(text: String) {
        Task {
            do {
                if vpsURL.isEmpty || authToken.isEmpty {
                    throw NSError(domain: "AgentWatch", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Configure VPS URL and token in Settings."])
                }
                // Connect fresh for each query (WebSocket auto-reconnect)
                let certHash = Bundle.main.object(forInfoDictionaryKey: "VPSCertSHA256") as? String
                try await vpsClient.connect(to: vpsURL, token: authToken, certHash: certHash)
                try await vpsClient.sendQuery(text: text, sessionID: currentSessionID)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }
}
