// VPSClient.swift
// URLSessionWebSocketTask-based client. Handles auth handshake, streaming chunks,
// cancel, and certificate pinning.
// PLATFORM NOTE: Requires Foundation/Network. Compilable on Linux for unit tests
// but WebSocket task requires Darwin runtime for actual connections.

import Foundation

@MainActor
final class VPSClient: NSObject, ObservableObject, URLSessionDelegate {

    enum ClientError: LocalizedError {
        case invalidURL
        case notConnected
        case authFailed
        case messageTooLarge
        case timeout
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid VPS URL."
            case .notConnected: return "Not connected to VPS."
            case .authFailed: return "Auth failed. Check token."
            case .messageTooLarge: return "Message too long (max 4096 chars)."
            case .timeout: return "Request timed out (15 s)."
            }
        }
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pinnedCertHash: String?
    private var isAuthenticated = false

    var onChunk: ((String, String) -> Void)?    // (text, session_id)
    var onDone: ((String) -> Void)?             // session_id
    var onError: ((String) -> Void)?            // message

    // MARK: - Public API

    func connect(to urlString: String, token: String, certHash: String?) async throws {
        guard let url = URL(string: urlString), urlString.hasPrefix("wss://") else {
            throw ClientError.invalidURL
        }
        pinnedCertHash = certHash

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        // Auth handshake
        let authMsg = AuthMessage(token: token)
        let authData = try JSONEncoder().encode(authMsg)
        try await webSocketTask?.send(.string(String(data: authData, encoding: .utf8)!))

        // Wait for auth_ok
        let response = try await webSocketTask?.receive()
        if case .string(let text) = response,
           let msg = try? JSONDecoder().decode(ServerMessage.self, from: Data(text.utf8)),
           msg.type == "auth_ok" {
            isAuthenticated = true
        } else {
            webSocketTask?.cancel(with: .policyViolation, reason: nil)
            throw ClientError.authFailed
        }

        // Start receive loop
        Task { await receiveLoop() }
    }

    func sendQuery(text: String, sessionID: String) async throws {
        guard isAuthenticated else { throw ClientError.notConnected }
        guard text.count <= 4096 else { throw ClientError.messageTooLarge }

        let msg = QueryMessage(text: text, session_id: sessionID)
        let data = try JSONEncoder().encode(msg)
        try await webSocketTask?.send(.string(String(data: data, encoding: .utf8)!))
    }

    func sendCancel(sessionID: String) async throws {
        let msg = CancelMessage(session_id: sessionID)
        let data = try JSONEncoder().encode(msg)
        try? await webSocketTask?.send(.string(String(data: data, encoding: .utf8)!))
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isAuthenticated = false
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }
        while true {
            do {
                let message = try await task.receive()
                if case .string(let text) = message {
                    handleServerMessage(text)
                }
            } catch {
                await MainActor.run { onError?(error.localizedDescription) }
                break
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(ServerMessage.self, from: data) else { return }

        Task { @MainActor in
            switch msg.type {
            case "chunk":
                if let chunkText = msg.text, let sid = msg.session_id {
                    onChunk?(chunkText, sid)
                }
            case "done":
                if let sid = msg.session_id { onDone?(sid) }
            case "error":
                onError?(msg.message ?? "Unknown error")
            default:
                break
            }
        }
    }

    // MARK: - Certificate Pinning (URLSessionDelegate)

    nonisolated func urlSession(_ session: URLSession,
                                 didReceive challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // If no pinned hash configured, fall back to default validation
        guard let pinnedHash = pinnedCertHash, !pinnedHash.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Evaluate trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Pin leaf certificate
        guard let cert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let certData = SecCertificateCopyData(cert) as Data
        let hash = sha256Hex(certData)

        if hash == pinnedHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        #if canImport(CryptoKit)
        import CryptoKit
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Placeholder for Linux builds — cert pinning not active
        return ""
        #endif
    }
}

// MARK: - Message Types

private struct AuthMessage: Encodable {
    let type = "auth"
    let token: String
}

private struct QueryMessage: Encodable {
    let type = "query"
    let text: String
    let session_id: String
}

private struct CancelMessage: Encodable {
    let type = "cancel"
    let session_id: String
}

struct ServerMessage: Decodable {
    let type: String
    let text: String?
    let session_id: String?
    let code: Int?
    let message: String?
}
