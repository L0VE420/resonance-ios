import Foundation

struct ResolvedStream: Sendable {
    let url: URL
    let format: String
    let bitrate: Int?
    let duration: TimeInterval?
}

enum StreamError: LocalizedError, Sendable {
    case unavailable
    case noPlayableFormat
    case signatureChallenge(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "This track is not currently available."
        case .noPlayableFormat:
            "No playable audio format was returned."
        case .signatureChallenge:
            "YouTube requires additional processing that is not yet supported in this build."
        }
    }
}

protocol StreamResolving: Sendable {
    func resolve(videoID: String) async throws -> ResolvedStream
}

actor YouTubeStreamResolver: StreamResolving {
    private let client: InnerTubeClient
    private let http: any HTTPTransport
    private let signatureSolver: JavaScriptSignatureSolver

    init(client: InnerTubeClient, http: any HTTPTransport, signatureSolver: JavaScriptSignatureSolver? = nil) {
        self.client = client
        self.http = http
        self.signatureSolver = signatureSolver ?? JavaScriptSignatureSolver()
    }

    func resolve(videoID: String) async throws -> ResolvedStream {
        let response = try await client.player(videoID: videoID)
        guard let formats = parseStreamingData(in: response) else { throw StreamError.unavailable }
        let format = pickFormat(from: formats) ?? formats.first
        guard let chosen = format else { throw StreamError.noPlayableFormat }
        let duration = response.values(forKey: "lengthSeconds")
            .compactMap { Double($0.stringValue ?? "") }
            .first
        let url = try await applySignature(chosen)
        return ResolvedStream(url: url, format: chosen.mime, bitrate: chosen.bitrate, duration: duration)
    }

    private struct StreamFormat: Sendable {
        let url: URL?
        let signatureCipher: String?
        let mime: String
        let bitrate: Int?
        let signature: String?

        var needsSignature: Bool { signatureCipher != nil || (signature != nil) }
    }

    private func parseStreamingData(in root: JSONValue) -> [StreamFormat]? {
        guard let streaming = root["streamingData"], streaming != .null else { return nil }
        var formats: [StreamFormat] = []
        for group in [streaming["formats"]?.arrayValue, streaming["adaptiveFormats"]?.arrayValue].compactMap({ $0 }) {
            for item in group {
                let mime = item["mimeType"]?.stringValue?.components(separatedBy: ";").first ?? "audio/mp4"
                guard mime.hasPrefix("audio/") else { continue }
                let url = item["url"]?.stringValue.flatMap(URL.init(string:))
                let cipher = item["signatureCipher"]?.stringValue
                let signature = item["signature"]?.stringValue
                let bitrate = item["bitrate"]?.doubleValue.map(Int.init)
                formats.append(StreamFormat(url: url, signatureCipher: cipher, mime: mime, bitrate: bitrate, signature: signature))
            }
        }
        return formats.isEmpty ? nil : formats
    }

    private func pickFormat(from formats: [StreamFormat]) -> StreamFormat? {
        let supported: Set<String> = ["audio/mp4", "audio/webm", "audio/ogg"]
        let progressive = formats.first { format in
            supported.contains(format.mime) && format.url != nil && format.signatureCipher == nil
        }
        if progressive != nil { return progressive }
        let adaptive = formats
            .filter { supported.contains($0.mime) && $0.needsSignature }
            .sorted { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }
        return adaptive.last ?? formats.first { supported.contains($0.mime) }
    }

    private func applySignature(_ format: StreamFormat) async throws -> URL {
        if let url = format.url, !format.needsSignature { return url }
        guard let challenge = parseSignatureChallenge(format) else { throw StreamError.noPlayableFormat }
        if challenge.n == nil && challenge.s == nil {
            throw StreamError.noPlayableFormat
        }
        if challenge.n == nil {
            throw StreamError.signatureChallenge("Missing n parameter")
        }
        let extracted = ExtractedChallenge(
            baseURL: challenge.baseURL,
            videoID: challenge.videoID,
            signature: challenge.signature,
            n: challenge.n,
            signatureQueryName: challenge.signatureQueryName,
            nQueryName: challenge.nQueryName
        )
        let solved = try await signatureSolver.solve(challenge: extracted, videoID: challenge.videoID ?? "")
        guard var components = URLComponents(url: challenge.baseURL, resolvingAgainstBaseURL: false) else {
            throw StreamError.noPlayableFormat
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: challenge.signatureQueryName ?? "sig", value: solved.signature),
            URLQueryItem(name: challenge.nQueryName ?? "n", value: solved.n)
        ].compactMap { $0.value == nil ? nil : $0 }
        guard let url = components.url else { throw StreamError.noPlayableFormat }
        return url
    }

    private struct SignatureChallenge: Sendable {
        let baseURL: URL
        let videoID: String?
        var signature: String?
        var n: String?
        var signatureQueryName: String?
        var nQueryName: String?
        var s: String?
    }

    struct ExtractedChallenge: Sendable {
        let baseURL: URL
        let videoID: String?
        let signature: String?
        let n: String?
        let signatureQueryName: String?
        let nQueryName: String?
    }

    private func parseSignatureChallenge(_ format: StreamFormat) -> SignatureChallenge? {
        let source = format.signatureCipher ?? format.signature
        guard let source, let baseURL = format.url else { return nil }
        var fields: [String: String] = [:]
        for pair in source.components(separatedBy: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            fields[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        return SignatureChallenge(
            baseURL: baseURL,
            videoID: fields["url"]?.components(separatedBy: "?").first?.components(separatedBy: "/").last,
            signature: fields["s"],
            n: fields["n"],
            signatureQueryName: fields["sp"] ?? "sig",
            nQueryName: "n",
            s: fields["s"]
        )
    }
}
