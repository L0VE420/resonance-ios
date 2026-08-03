import XCTest
@testable import Resonance

final class HTTPClientTests: XCTestCase {
    func testRetriesRecoverableError() async throws {
        let transport = StubTransport(behaviors: [
            .fail(URLError(.timedOut)),
            .fail(URLError(.networkConnectionLost)),
            .respond(Data("ok".utf8), status: 200)
        ])
        let http = HTTPClient(session: URLSession(configuration: .ephemeral))
        _ = http
        let (data, _) = try await transport.data(for: URLRequest(url: URL(string: "https://example.com")!), attempts: 3)
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
    }

    func testPropagatesNonRecoverableError() async {
        let transport = StubTransport(behaviors: [.fail(URLError(.badURL))])
        do {
            _ = try await transport.data(for: URLRequest(url: URL(string: "https://example.com")!), attempts: 2)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}

private struct StubResponse {
    enum Behavior {
        case respond(Data, status: Int)
        case fail(Error)
    }
    let behavior: Behavior
}

private final class StubTransport: HTTPTransport, @unchecked Sendable {
    private var behaviors: [StubResponse.Behavior]
    init(behaviors: [StubResponse.Behavior]) { self.behaviors = behaviors }

    func data(for request: URLRequest, attempts: Int) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = URLError(.unknown)
        for attempt in 1...attempts {
            guard !behaviors.isEmpty else { break }
            let behavior = behaviors.removeFirst()
            switch behavior {
            case .respond(let data, let status):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (data, response)
            case .fail(let error):
                lastError = error
            }
        }
        throw lastError
    }
}
