import Foundation

actor InnerTubeClient {
    private let http: any HTTPTransport
    private let decoder = JSONDecoder()
    private var visitorData: String?
    private var locale: Locale

    init(http: any HTTPTransport, locale: Locale = .current) {
        self.http = http
        self.locale = locale
    }

    func updateLocale(_ locale: Locale) {
        self.locale = locale
    }

    func home(continuation: String? = nil) async throws -> JSONValue {
        if let continuation {
            return try await request(.browse, fields: ["continuation": .string(continuation)])
        }
        return try await request(.browse, fields: ["browseId": .string("FEmusic_home")])
    }

    func searchSuggestions(query: String) async throws -> JSONValue {
        try await request(.searchSuggestions, fields: ["input": .string(query)])
    }

    func search(query: String, continuation: String? = nil) async throws -> JSONValue {
        var fields: [String: JSONValue] = ["query": .string(query)]
        if let continuation { fields["continuation"] = .string(continuation) }
        return try await request(.search, fields: fields)
    }

    func browse(id: String, params: String? = nil, continuation: String? = nil) async throws -> JSONValue {
        var fields: [String: JSONValue] = [:]
        if let continuation {
            fields["continuation"] = .string(continuation)
        } else {
            fields["browseId"] = .string(id)
            if let params { fields["params"] = .string(params) }
        }
        return try await request(.browse, fields: fields)
    }

    func player(videoID: String, playlistID: String? = nil) async throws -> JSONValue {
        var fields: [String: JSONValue] = [
            "videoId": .string(videoID),
            "contentCheckOk": .bool(true),
            "racyCheckOk": .bool(true)
        ]
        if let playlistID { fields["playlistId"] = .string(playlistID) }
        return try await request(.player, profile: .iOS, fields: fields)
    }

    func webPlayer(videoID: String, signatureTimestamp: Int? = nil) async throws -> JSONValue {
        var fields: [String: JSONValue] = [
            "videoId": .string(videoID),
            "contentCheckOk": .bool(true),
            "racyCheckOk": .bool(true)
        ]
        if let signatureTimestamp {
            fields["playbackContext"] = .object([
                "contentPlaybackContext": .object([
                    "signatureTimestamp": .number(Double(signatureTimestamp))
                ])
            ])
        }
        return try await request(.player, profile: .webRemix, fields: fields)
    }

    func next(videoID: String, playlistID: String? = nil) async throws -> JSONValue {
        var fields: [String: JSONValue] = ["videoId": .string(videoID)]
        if let playlistID { fields["playlistId"] = .string(playlistID) }
        return try await request(.next, fields: fields)
    }

    func lyricsBrowseID(videoID: String) async throws -> String? {
        let response = try await next(videoID: videoID)
        return response.values(forKey: "browseId")
            .compactMap(\.stringValue)
            .first { $0.hasPrefix("MPLYt") || $0.hasPrefix("MPLYw") }
    }

    private func request(
        _ endpoint: InnerTubeEndpoint,
        profile: YouTubeClientProfile = .webRemix,
        fields: [String: JSONValue]
    ) async throws -> JSONValue {
        var payload = fields
        payload["context"] = profile.context(visitorData: visitorData, locale: locale)
        let request = try InnerTubeRequestFactory.request(
            endpoint: endpoint,
            profile: profile,
            body: .object(payload)
        )
        let (data, _) = try await http.data(for: request, attempts: 3)
        let response = try decoder.decode(JSONValue.self, from: data)
        if let updatedVisitorData = response.firstString(forKey: "visitorData"), !updatedVisitorData.isEmpty {
            visitorData = updatedVisitorData
        }
        return response
    }
}
