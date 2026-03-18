// StreamingParser.swift — AgentWatchCore
// JSON-lines parser for WebSocket streaming. Pure Swift, no platform deps.
// Fully testable on Linux.

import Foundation

/// Accumulates a running buffer of UTF-8 text and extracts complete JSON-lines messages.
public final class StreamingParser: @unchecked Sendable {
    private var buffer: String = ""
    private let decoder = JSONDecoder()

    public init() {}

    /// Feed raw text received from the WebSocket.
    /// Returns any complete `ServerMessage` objects decoded from complete lines.
    public func feed(_ text: String) -> [ServerMessage] {
        buffer += text
        var results: [ServerMessage] = []

        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8),
                  let msg = try? decoder.decode(ServerMessage.self, from: data)
            else { continue }
            results.append(msg)
        }
        return results
    }

    /// Reset internal buffer (e.g., on new session).
    public func reset() {
        buffer = ""
    }

    /// Validate a URL string is a proper wss:// endpoint.
    public static func validateVPSURL(_ urlString: String) -> Bool {
        guard urlString.hasPrefix("wss://"),
              let url = URL(string: urlString),
              url.host != nil
        else { return false }
        return true
    }

    /// Build a JSON-lines encoded string for a client query message.
    public static func encodeQuery(text: String, sessionID: String) throws -> String {
        let msg = ClientQueryMessage(text: text, sessionID: sessionID)
        let data = try JSONEncoder().encode(msg)
        return String(data: data, encoding: .utf8)! + "\n"
    }
}
