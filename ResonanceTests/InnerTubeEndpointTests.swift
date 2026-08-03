import XCTest
@testable import Resonance

final class InnerTubeEndpointTests: XCTestCase {
    func testBuildsRequestHeaders() throws {
        let body: JSONValue = .object([
            "context": .object([
                "client": .object(["clientName": .string("WEB_REMIX")])
            ]),
            "browseId": .string("FEmusic_home")
        ])
        let request = try InnerTubeRequestFactory.request(
            endpoint: .browse,
            profile: .webRemix,
            body: body
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-YouTube-Client-Name"), "67")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-YouTube-Client-Version"), "1.20260213.01.00")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://music.youtube.com")
        XCTAssertTrue(request.url?.query?.contains("prettyPrint=false") ?? false)
    }

    func testIncludesVisitorDataWhenAvailable() {
        let context = YouTubeClientProfile.webRemix.context(
            visitorData: "CgASAA",
            locale: Locale(identifier: "fr_FR")
        )
        XCTAssertEqual(context["client"]?["hl"]?.stringValue, "fr")
        XCTAssertEqual(context["client"]?["gl"]?.stringValue, "FR")
        XCTAssertEqual(context["client"]?["visitorData"]?.stringValue, "CgASAA")
    }
}
