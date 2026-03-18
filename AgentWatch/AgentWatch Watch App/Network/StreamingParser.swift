// StreamingParser.swift
// Reassembles JSON-lines chunks from the WebSocket stream.
// This is a thin wrapper — the actual JSON-lines logic lives in AgentWatchCore
// (Linux-testable). This file bridges to the Watch's MainActor UI.

import Foundation

/// Accumulates streamed JSON-line text and extracts complete messages.
final class StreamingParser {
    private var buffer: String = ""

    /// Feed raw text from the WebSocket receive loop.
    /// Returns any complete JSON-line messages found.
    func feed(_ text: String) -> [ServerMessage] {
        buffer += text
        var results: [ServerMessage] = []

        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let msg = try? JSONDecoder().decode(ServerMessage.self, from: data)
            else { continue }
            results.append(msg)
        }
        return results
    }

    func reset() { buffer = "" }
}
