// StreamingParserTests.swift
import XCTest
@testable import AgentWatchCore

final class StreamingParserTests: XCTestCase {

    var parser: StreamingParser!

    override func setUp() {
        super.setUp()
        parser = StreamingParser()
    }

    func testSingleCompleteLine() {
        let json = "{\"type\":\"chunk\",\"text\":\"Hello\",\"session_id\":\"s1\"}\n"
        let results = parser.feed(json)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].type, "chunk")
        XCTAssertEqual(results[0].text, "Hello")
    }

    func testPartialLineThenComplete() {
        let part1 = "{\"type\":\"chunk\",\"text\":\"Hel"
        let part2 = "lo\",\"session_id\":\"s1\"}\n"
        let r1 = parser.feed(part1)
        XCTAssertEqual(r1.count, 0, "Partial line should yield nothing")
        let r2 = parser.feed(part2)
        XCTAssertEqual(r2.count, 1)
        XCTAssertEqual(r2[0].text, "Hello")
    }

    func testMultipleLinesInOneFeed() {
        let json = """
        {"type":"chunk","text":"Paris","session_id":"s1"}
        {"type":"done","session_id":"s1"}

        """
        let results = parser.feed(json)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].type, "chunk")
        XCTAssertEqual(results[1].type, "done")
    }

    func testInvalidJSONSkipped() {
        let json = "not-json\n{\"type\":\"done\",\"session_id\":\"s1\"}\n"
        let results = parser.feed(json)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].type, "done")
    }

    func testReset() {
        _ = parser.feed("{\"type\":\"chunk\",\"text\":\"partial")
        parser.reset()
        let results = parser.feed("{\"type\":\"done\",\"session_id\":\"s2\"}\n")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].type, "done")
    }

    func testEmptyLinesSkipped() {
        let json = "\n\n{\"type\":\"done\",\"session_id\":\"s1\"}\n\n"
        let results = parser.feed(json)
        XCTAssertEqual(results.count, 1)
    }

    func testValidateVPSURL() {
        XCTAssertTrue(StreamingParser.validateVPSURL("wss://my-vps.example.com:443/ws"))
        XCTAssertTrue(StreamingParser.validateVPSURL("wss://192.168.1.100:8443/ws"))
        XCTAssertFalse(StreamingParser.validateVPSURL("ws://insecure.example.com/ws"))
        XCTAssertFalse(StreamingParser.validateVPSURL("https://wrong.example.com"))
        XCTAssertFalse(StreamingParser.validateVPSURL(""))
    }

    func testEncodeQuery() throws {
        let encoded = try StreamingParser.encodeQuery(text: "Hello AI", sessionID: "sess-1")
        XCTAssertTrue(encoded.hasSuffix("\n"), "Should be newline-terminated")
        let data = Data(encoded.utf8.dropLast())  // remove trailing newline
        let msg = try JSONDecoder().decode(ClientQueryMessage.self, from: data)
        XCTAssertEqual(msg.text, "Hello AI")
        XCTAssertEqual(msg.session_id, "sess-1")
    }
}
