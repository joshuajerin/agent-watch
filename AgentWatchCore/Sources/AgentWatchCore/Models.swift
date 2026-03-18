// Models.swift — AgentWatchCore
// Shared data models used by both the watchOS app and Linux unit tests.
// No platform-specific imports; pure Swift.

import Foundation

// MARK: - App Phase

public enum AppPhase: Equatable, Sendable {
    case idle
    case listening
    case thinking
    case responding
    case error(String)
}

// MARK: - Conversation

public struct ConversationTurn: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let query: String
    public let response: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), query: String, response: String) {
        self.id = id
        self.timestamp = timestamp
        self.query = query
        self.response = response
    }
}

// MARK: - WebSocket Messages

public struct ClientAuthMessage: Encodable, Sendable {
    public let type: String = "auth"
    public let token: String
    public init(token: String) { self.token = token }
}

public struct ClientQueryMessage: Encodable, Sendable {
    public let type: String = "query"
    public let text: String
    public let session_id: String
    public init(text: String, sessionID: String) {
        self.text = text
        self.session_id = sessionID
    }
}

public struct ClientCancelMessage: Encodable, Sendable {
    public let type: String = "cancel"
    public let session_id: String
    public init(sessionID: String) { self.session_id = sessionID }
}

public struct ServerMessage: Decodable, Sendable {
    public let type: String
    public let text: String?
    public let session_id: String?
    public let code: Int?
    public let message: String?

    public init(type: String, text: String? = nil, session_id: String? = nil,
                code: Int? = nil, message: String? = nil) {
        self.type = type
        self.text = text
        self.session_id = session_id
        self.code = code
        self.message = message
    }
}

// MARK: - Settings

public struct AgentWatchSettings: Codable, Sendable {
    public var vpsURL: String
    public var certSHA256: String
    public var voiceRate: Double
    public var voicePitch: Double

    public init(vpsURL: String = "", certSHA256: String = "",
                voiceRate: Double = 0.5, voicePitch: Double = 1.0) {
        self.vpsURL = vpsURL
        self.certSHA256 = certSHA256
        self.voiceRate = voiceRate
        self.voicePitch = voicePitch
    }

    public var isConfigured: Bool {
        !vpsURL.isEmpty && vpsURL.hasPrefix("wss://")
    }
}
