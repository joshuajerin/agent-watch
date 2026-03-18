// ConversationStore.swift
// Persists last 20 conversation turns to UserDefaults (device-encrypted at rest).
// Sensitive content (query/response text) is acceptable in UserDefaults on watchOS
// as the storage is protected by the device's hardware encryption.

import Foundation

struct ConversationTurn: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let query: String
    let response: String
}

final class ConversationStore: ObservableObject {
    private static let maxTurns = 20
    private static let defaultsKey = "conversation_history"

    @Published private(set) var turns: [ConversationTurn] = []

    init() {
        load()
    }

    func append(query: String, response: String) {
        let turn = ConversationTurn(id: UUID(), timestamp: Date(), query: query, response: response)
        turns.append(turn)
        if turns.count > Self.maxTurns {
            turns.removeFirst(turns.count - Self.maxTurns)
        }
        save()
    }

    func clear() {
        turns = []
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(turns) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([ConversationTurn].self, from: data)
        else { return }
        turns = decoded
    }
}
