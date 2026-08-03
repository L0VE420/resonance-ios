import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest, attempts: Int) async throws -> (Data, HTTPURLResponse)
}

enum HTTPError: LocalizedError, Sendable {
    case invalidResponse
    case status(Int, Data)
    case exhaustedRetries(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case .status(let code, _):
            "The server returned HTTP \(code)."
        case .exhaustedRetries(let message):
            "The request failed after retrying: \(message)"
        }
    }
}

final class HTTPClient: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 90
            configuration.requestCachePolicy = .useProtocolCachePolicy
            configuration.urlCache = URLCache(
                memoryCapacity: 16 * 1024 * 1024,
                diskCapacity: 50 * 1024 * 1024
            )
            configuration.httpMaximumConnectionsPerHost = 8
            self.session = URLSession(configuration: configuration)
        }
    }

    func data(for request: URLRequest, attempts: Int = 3) async throws -> (Data, HTTPURLResponse) {
        precondition(attempts > 0)
        var delay: UInt64 = 500_000_000
        var lastError: Error = URLError(.unknown)

        for attempt in 1...attempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HTTPError.invalidResponse
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    if (500..<600).contains(httpResponse.statusCode), attempt < attempts {
                        try await Task.sleep(nanoseconds: delay)
                        delay *= 2
                        continue
                    }
                    throw HTTPError.status(httpResponse.statusCode, data)
                }
                return (data, httpResponse)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                guard attempt < attempts, shouldRetry(error) else { throw error }
                try await Task.sleep(nanoseconds: delay)
                delay *= 2
            }
        }

        throw HTTPError.exhaustedRetries(lastError.localizedDescription)
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return [
            .timedOut,
            .cannotConnectToHost,
            .networkConnectionLost,
            .notConnectedToInternet,
            .dnsLookupFailed,
            .resourceUnavailable
        ].contains(urlError.code)
    }
}
