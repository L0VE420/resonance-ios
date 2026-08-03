import Foundation

protocol LyricsProvider: Sendable {
    var name: String { get }
    func lyrics(for track: Track) async throws -> LyricsDocument?
}

final class LyricsService: Sendable {
    private let providers: [any LyricsProvider]

    init(providers: [any LyricsProvider]) {
        self.providers = providers
    }

    func lyrics(for track: Track) async -> LyricsDocument? {
        for provider in providers {
            do {
                if let document = try await provider.lyrics(for: track), !document.lines.isEmpty {
                    return document
                }
            } catch is CancellationError {
                return nil
            } catch {
                continue
            }
        }
        return nil
    }
}

struct LRCParser: Sendable {
    func parse(_ value: String, source: String) -> LyricsDocument? {
        let lines = value.components(separatedBy: .newlines)
        var parsed: [(time: TimeInterval, text: String)] = []
        let pattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            let matches = expression.matches(in: line, range: range)
            guard !matches.isEmpty else { continue }
            let text = expression.stringByReplacingMatches(in: line, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            for match in matches {
                guard let minutes = Int(nsLine.substring(with: match.range(at: 1))),
                      let seconds = Double(nsLine.substring(with: match.range(at: 2))) else { continue }
                let fraction: Double
                if match.range(at: 3).location != NSNotFound, let raw = Double(nsLine.substring(with: match.range(at: 3))) {
                    fraction = raw / (raw < 10 ? 10 : raw < 100 ? 100 : 1000)
                } else {
                    fraction = 0
                }
                parsed.append((Double(minutes) * 60 + seconds + fraction, text))
            }
        }

        guard !parsed.isEmpty else { return nil }
        parsed.sort { $0.time < $1.time }
        let result = parsed.enumerated().map { index, item in
            LyricsLine(
                startTime: item.time,
                endTime: parsed.indices.contains(index + 1) ? parsed[index + 1].time : nil,
                text: item.text,
                isInstrumental: item.text.isEmpty
            )
        }
        return LyricsDocument(source: source, lines: result, isSynced: true)
    }

    func parsePlain(_ value: String, source: String) -> LyricsDocument? {
        let lines = value.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        return LyricsDocument(
            source: source,
            lines: lines.map { LyricsLine(startTime: 0, text: $0) },
            isSynced: false
        )
    }

    func activeLineIndex(in document: LyricsDocument, at time: TimeInterval) -> Int? {
        guard !document.lines.isEmpty else { return nil }
        return document.lines.lastIndex { $0.startTime <= max(0, time) }
    }
}

struct YouTubeLyricsProvider: LyricsProvider {
    let name = "YouTube Music"
    let client: InnerTubeClient
    private let parser = LRCParser()

    init(client: InnerTubeClient) {
        self.client = client
    }

    func lyrics(for track: Track) async throws -> LyricsDocument? {
        guard let browseID = try await client.lyricsBrowseID(videoID: track.videoID) else { return nil }
        let response = try await client.browse(id: browseID)
        let text = response.values(forKey: "lyricLine")
            .compactMap { $0.text() }
            .joined(separator: "\n")
        guard !text.isEmpty else { return nil }
        return parser.parsePlain(text, source: name)
    }
}

struct LRCLIBLyricsProvider: LyricsProvider {
    let name = "LRCLIB"
    let http: any HTTPTransport
    private let parser = LRCParser()

    init(http: any HTTPTransport) {
        self.http = http
    }

    func lyrics(for track: Track) async throws -> LyricsDocument? {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else { return nil }
        var query: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artistText)
        ]
        if let album = track.album?.title { query.append(URLQueryItem(name: "album_name", value: album)) }
        if let duration = track.duration { query.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        components.queryItems = query
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Resonance/0.1 (personal testing)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await http.data(for: request, attempts: 2)
        let response = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
        if let synced = response.syncedLyrics, let document = parser.parse(synced, source: name) { return document }
        if let plain = response.plainLyrics { return parser.parsePlain(plain, source: name) }
        return nil
    }

    private struct LRCLIBResponse: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?

        enum CodingKeys: String, CodingKey {
            case syncedLyrics = "syncedLyrics"
            case plainLyrics = "plainLyrics"
        }
    }
}
