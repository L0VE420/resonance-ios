import XCTest
@testable import Resonance

final class LyricsParserTests: XCTestCase {
    private let parser = LRCParser()

    func testParsesSyncedLyrics() {
        guard let url = Bundle.module.url(forResource: "lyrics", withExtension: "lrc"),
              let data = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Missing lyrics fixture")
            return
        }
        let document = parser.parse(data, source: "fixture")
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.source, "fixture")
        XCTAssertTrue(document?.isSynced ?? false)
        XCTAssertEqual(document?.lines.first?.text, "Line one")
        XCTAssertEqual(document?.lines.count, 4)
    }

    func testIdentifiesActiveLine() {
        let document = parser.parse("[00:00.00]A\n[00:02.00]B", source: "fixture")!
        XCTAssertEqual(parser.activeLineIndex(in: document, at: 0.5), 0)
        XCTAssertEqual(parser.activeLineIndex(in: document, at: 2.5), 1)
    }

    func testReturnsNilForEmptyLyrics() {
        XCTAssertNil(parser.parse("", source: "fixture"))
    }
}
