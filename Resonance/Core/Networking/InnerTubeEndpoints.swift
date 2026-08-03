import Foundation

struct YouTubeClientProfile: Sendable {
    let name: String
    let id: String
    let version: String
    let userAgent: String
    let origin: String

    static let webRemix = YouTubeClientProfile(
        name: "WEB_REMIX",
        id: "67",
        version: "1.20260213.01.00",
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0",
        origin: "https://music.youtube.com"
    )

    static let iOS = YouTubeClientProfile(
        name: "IOS",
        id: "5",
        version: "21.03.1",
        userAgent: "com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)",
        origin: "https://www.youtube.com"
    )

    func context(visitorData: String?, locale: Locale) -> JSONValue {
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        return .object([
            "client": .object([
                "clientName": .string(name),
                "clientVersion": .string(version),
                "hl": .string(language),
                "gl": .string(region),
                "visitorData": visitorData.map(JSONValue.string),
                "userAgent": .string(userAgent)
            ].compactMapValues { $0 })
        ])
    }
}

enum InnerTubeEndpoint: String, Sendable {
    case browse
    case search
    case player
    case next
    case searchSuggestions = "music/get_search_suggestions"
}

enum InnerTubeRequestFactory {
    static let baseURL = URL(string: "https://music.youtube.com/youtubei/v1/")!

    static func request(
        endpoint: InnerTubeEndpoint,
        profile: YouTubeClientProfile,
        body: JSONValue
    ) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.rawValue),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "prettyPrint", value: "false")]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(profile.id, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(profile.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(profile.origin, forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue(profile.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}
