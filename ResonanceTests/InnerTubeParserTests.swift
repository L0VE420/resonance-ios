import XCTest
@testable import Resonance

final class InnerTubeParserTests: XCTestCase {
    private let parser = InnerTubeParser()

    func testParsesHomeShelves() throws {
        let data = try fixtureData("home-response.json")
        let response = try JSONDecoder().decode(JSONValue.self, from: data)
        let page = parser.parsePage(response, fallbackTitle: "Home")
        XCTAssertEqual(page.title, "Home")
        XCTAssertGreaterThanOrEqual(page.sections.count, 2)
        let firstSection = page.sections[0]
        XCTAssertEqual(firstSection.title, "Quick picks")
        XCTAssertEqual(firstSection.items.count, 2)
        if case .track(let track) = firstSection.items[0] {
            XCTAssertEqual(track.videoID, "dQw4w9WgXcQ")
            XCTAssertEqual(track.title, "Echoes")
            XCTAssertEqual(track.artists.first?.name, "Pink Floyd")
        } else {
            XCTFail("Expected first hero item to be a track")
        }
    }

    func testParsesSearchResponse() throws {
        let data = try fixtureData("search-response.json")
        let response = try JSONDecoder().decode(JSONValue.self, from: data)
        let page = parser.parsePage(response, fallbackTitle: "Results")
        XCTAssertEqual(page.sections.first?.title, "Songs")
        if case .track(let track) = page.sections.first?.items.first ?? .track(Track(videoID: "", title: "")) {
            XCTAssertEqual(track.videoID, "abc123")
            XCTAssertEqual(track.title, "Sample")
            XCTAssertEqual(track.artistText, "Artist A")
            XCTAssertEqual(track.duration, 222)
            XCTAssertTrue(track.explicit)
        } else {
            XCTFail("Expected track")
        }
    }

    func testDeduplicatesAcrossRendererKeys() {
        let response: JSONValue = .object([
            "musicShelfRenderer": .object([
                "contents": .array([
                    .object([
                        "musicTwoRowItemRenderer": .object([
                            "title": .object(["runs": .array([.string("Echoes")])]),
                            "navigationEndpoint": .object([
                                "watchEndpoint": .object(["videoId": .string("v1")])
                            ])
                        ])
                    ])
                ])
            ])
        ])
        let page = parser.parsePage(response, fallbackTitle: "Library")
        XCTAssertEqual(page.tracks.map(\.videoID), ["v1"])
    }

    private func fixtureData(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw NSError(domain: "Fixtures", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(name)"])
        }
        return try Data(contentsOf: url)
    }
}
