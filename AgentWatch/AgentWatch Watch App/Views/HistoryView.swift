// HistoryView.swift
// Scrollable conversation transcript — last 20 turns, Digital Crown scrollable.

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            if appState.conversationStore.turns.isEmpty {
                VStack {
                    Spacer()
                    Text("no history")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.conversationStore.turns.reversed()) { turn in
                            TurnView(turn: turn)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .focusable()
                .digitalCrownRotation(
                    Binding.constant(0.0),
                    from: 0,
                    through: Double(appState.conversationStore.turns.count),
                    by: 1.0
                )
            }
        }
        .navigationTitle("History")
    }
}

private struct TurnView: View {
    let turn: ConversationTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("YOU")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                Text(turn.timestamp, style: .time)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Text(turn.query)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white)

            Text("AI")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
                .padding(.top, 2)
            Text(turn.response)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
                .opacity(0.85)
        }
        .padding(6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
