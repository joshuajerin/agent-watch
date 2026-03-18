// ModelsTests.swift
import XCTest
@testable import AgentWatchCore

final class ModelsTests: XCTestCase {

    func testConversationTurnCodable() throws {
        let turn = ConversationTurn(id: UUID(), timestamp: Date(timeIntervalSince1970: 0),
                                   query: "Hello", response: "World")
        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(ConversationTurn.self, from: data)
        XCTAssertEqual(turn.query, decoded.query)
        XCTAssertEqual(turn.response, decoded.response)
        XCTAssertEqual(turn.id, decoded.id)
    }

    func testServerMessageDecoding() throws {
        let json = """
        {"type":"chunk","text":"Hello","session_id":"abc-123"}
        """
        let msg = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        XCTAssertEqual(msg.type, "chunk")
        XCTAssertEqual(msg.text, "Hello")
        XCTAssertEqual(msg.session_id, "abc-123")
    }

    func testClientQueryMessageEncoding() throws {
        let msg = ClientQueryMessage(text: "What is 2+2?", sessionID: "sess-1")
        let data = try JSONEncoder().encode(msg)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: String]
        XCTAssertEqual(dict["type"], "query")
        XCTAssertEqual(dict["text"], "What is 2+2?")
        XCTAssertEqual(dict["session_id"], "sess-1")
    }

    func testSettingsValidation() {
        var settings = AgentWatchSettings()
        XCTAssertFalse(settings.isConfigured)

        settings.vpsURL = "wss://my-vps.example.com:443/ws"
        XCTAssertTrue(settings.isConfigured)

        settings.vpsURL = "ws://insecure.example.com"
        XCTAssertFalse(settings.isConfigured, "Plain ws:// should fail isConfigured")

        settings.vpsURL = "https://wrong-scheme.example.com"
        XCTAssertFalse(settings.isConfigured)
    }

    func testAppPhaseEquality() {
        XCTAssertEqual(AppPhase.idle, AppPhase.idle)
        XCTAssertEqual(AppPhase.error("oops"), AppPhase.error("oops"))
        XCTAssertNotEqual(AppPhase.idle, AppPhase.listening)
        XCTAssertNotEqual(AppPhase.error("a"), AppPhase.error("b"))
    }

    func testAuthMessageEncoding() throws {
        let msg = ClientAuthMessage(token: "secret-token-123")
        let data = try JSONEncoder().encode(msg)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: String]
        XCTAssertEqual(dict["type"], "auth")
        XCTAssertEqual(dict["token"], "secret-token-123")
    }

    func testCancelMessageEncoding() throws {
        let msg = ClientCancelMessage(sessionID: "sess-42")
        let data = try JSONEncoder().encode(msg)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: String]
        XCTAssertEqual(dict["type"], "cancel")
        XCTAssertEqual(dict["session_id"], "sess-42")
    }
}
