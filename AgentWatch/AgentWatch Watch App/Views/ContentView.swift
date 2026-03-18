// ContentView.swift
// Root view: terminal-style display with three states — idle, listening, responding.
// Voice input only: Digital Crown press-to-talk via WKExtendedRuntimeSession
// or crown press gesture. No keyboard input.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch appState.phase {
            case .idle:
                IdleView()
            case .listening:
                ListeningView()
            case .thinking:
                ThinkingView()
            case .responding:
                RespondingView()
            case .error(let message):
                ErrorView(message: message)
            }
        }
        .onTapGesture(count: 2) {
            // Double-tap: cancel in-flight request or return to idle
            appState.cancel()
        }
    }
}

// MARK: - Sub-views

private struct IdleView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("AGENT WATCH")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
                .opacity(0.6)
            Spacer()
            Button(action: { appState.startListening() }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            Text("press to speak")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
                .opacity(0.4)
            Spacer()
        }
    }
}

private struct ListeningView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("LISTENING")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.top, 4)

            ScrollView {
                Text(appState.partialTranscript.isEmpty ? "..." : appState.partialTranscript)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.1), value: appState.partialTranscript)
            }

            Button("Send") {
                appState.submitTranscript()
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.green)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
    }
}

private struct ThinkingView: View {
    @State private var dotCount = 1

    var body: some View {
        VStack(spacing: 8) {
            Text(String(repeating: ".", count: dotCount))
                .font(.system(.title3, design: .monospaced))
                .foregroundColor(.yellow)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        dotCount = (dotCount % 3) + 1
                    }
                }
            Text("thinking")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.yellow)
                .opacity(0.6)
        }
    }
}

private struct RespondingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("> ")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Button(action: { appState.cancel() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                Text(appState.responseBuffer)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeIn(duration: 0.05), value: appState.responseBuffer)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct ErrorView: View {
    @EnvironmentObject var appState: AppState
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text("ERROR")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.red)
            Text(message)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.red)
                .opacity(0.8)
                .multilineTextAlignment(.center)
            Button("Retry") { appState.reset() }
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
