import Foundation

struct InnerTubeParser: Sendable {
    func parsePage(_ root: JSONValue, fallbackTitle: String = "Music") -> CatalogPage {
        var sections: [BrowseSection] = []
        let shelfKeys = [
            "musicCarouselShelfRenderer",
            "musicShelfRenderer",
            "musicPlaylistShelfRenderer",
            "gridRenderer"
        ]

        for key in shelfKeys {
            for (index, shelf) in root.values(forKey: key).enumerated() {
                guard let section = parseSection(shelf, fallbackID: "\(key)-\(index)"), !section.items.isEmpty else {
                    continue
                }
                if !sections.contains(where: { $0.items == section.items }) {
                    sections.append(section)
                }
            }
        }

        if sections.isEmpty {
            let items = parseAllItems(in: root)
            if !items.isEmpty {
                sections = [BrowseSection(id: "results", title: fallbackTitle, items: items)]
            }
        }

        let title = headerText(in: root, keys: ["musicDetailHeaderRenderer", "musicEditablePlaylistDetailHeaderRenderer", "musicVisualHeaderRenderer"]) ?? fallbackTitle
        let subtitle = root.values(forKey: "subtitle").compactMap { $0.text() }.first
        return CatalogPage(
            title: title,
            subtitle: subtitle,
            artworkURL: bestThumbnail(in: root),
            sections: sections,
            continuation: continuation(in: root)
        )
    }

    func parseSuggestions(_ root: JSONValue) -> [String] {
        var suggestions: [String] = []
        for renderer in root.values(forKey: "searchSuggestionRenderer") {
            if let suggestion = renderer["suggestion"]?.text(), !suggestion.isEmpty {
                suggestions.append(suggestion)
            }
        }
        if suggestions.isEmpty {
            suggestions = root.values(forKey: "query").compactMap(\.stringValue)
        }
        return unique(suggestions)
    }

    private func parseSection(_ shelf: JSONValue, fallbackID: String) -> BrowseSection? {
        let title = shelf["header"]?.values(forKey: "title").compactMap { $0.text() }.first
            ?? shelf["title"]?.text()
            ?? "For you"
        let contents = shelf["contents"]?.arrayValue ?? []
        let items = unique(contents.compactMap(parseItem))
        guard !items.isEmpty else { return nil }
        return BrowseSection(id: "\(fallbackID)-\(slug(title))", title: title, items: items)
    }

    private func parseAllItems(in root: JSONValue) -> [CatalogItem] {
        let keys = [
            "musicResponsiveListItemRenderer",
            "musicTwoRowItemRenderer",
            "musicMultiRowListItemRenderer"
        ]
        return unique(keys.flatMap { root.values(forKey: $0).compactMap(parseRenderer) })
    }

    private func parseItem(_ node: JSONValue) -> CatalogItem? {
        for key in ["musicResponsiveListItemRenderer", "musicTwoRowItemRenderer", "musicMultiRowListItemRenderer"] {
            if let renderer = node[key], let item = parseRenderer(renderer) {
                return item
            }
        }
        return parseRenderer(node)
    }

    private func parseRenderer(_ renderer: JSONValue) -> CatalogItem? {
        let columns = renderer["flexColumns"]?.arrayValue?.compactMap {
            $0["musicResponsiveListItemFlexColumnRenderer"]?["text"]?.text()
        } ?? []
        let title = renderer["title"]?.text() ?? columns.first ?? renderer.firstString(forKey: "title")
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let subtitle = renderer["subtitle"]?.text()
            ?? columns.dropFirst().first
            ?? renderer["longBylineText"]?.text()
            ?? ""
        let artworkURL = bestThumbnail(in: renderer)
        let videoID = renderer.firstString(forKey: "videoId")
        let browseIDs = renderer.values(forKey: "browseId").compactMap(\.stringValue)
        let browseID = browseIDs.first

        if let videoID, !videoID.isEmpty {
            let artistName = subtitleParts(subtitle).first ?? "Unknown artist"
            let artistBrowseID = browseIDs.first { $0.hasPrefix("UC") }
            let albumBrowseID = browseIDs.first { $0.hasPrefix("MPRE") }
            let albumTitle = subtitleParts(subtitle).dropFirst().first
            let track = Track(
                videoID: videoID,
                title: title,
                artists: [Artist(id: artistBrowseID ?? slug(artistName), name: artistName, browseID: artistBrowseID)],
                album: albumBrowseID.map { AlbumSummary(id: $0, title: albumTitle ?? "Album", browseID: $0) },
                duration: duration(from: subtitle) ?? renderer.values(forKey: "lengthText").compactMap { duration(from: $0.text() ?? "") }.first,
                artworkURL: artworkURL,
                explicit: renderer.firstString(forKey: "iconType") == "MUSIC_EXPLICIT_BADGE"
            )
            return .track(track)
        }

        guard let browseID else { return nil }
        if browseID.hasPrefix("UC") {
            return .artist(Artist(id: browseID, name: title, browseID: browseID, artworkURL: artworkURL))
        }
        if browseID.hasPrefix("MPRE") || browseID.hasPrefix("FEmusic_library_corpus_track_artists") {
            let artistName = subtitleParts(subtitle).first ?? ""
            let artists = artistName.isEmpty ? [] : [Artist(id: slug(artistName), name: artistName)]
            return .album(Album(
                browseID: browseID,
                title: title,
                artists: artists,
                artworkURL: artworkURL,
                year: subtitleParts(subtitle).first { $0.count == 4 && Int($0) != nil }
            ))
        }
        if browseID.hasPrefix("VL") || browseID.hasPrefix("PL") || browseID.hasPrefix("OLAK") {
            return .playlist(Playlist(
                browseID: browseID,
                title: title,
                owner: subtitleParts(subtitle).first,
                artworkURL: artworkURL,
                trackCountText: subtitleParts(subtitle).first { $0.localizedCaseInsensitiveContains("song") }
            ))
        }
        return nil
    }

    private func headerText(in root: JSONValue, keys: [String]) -> String? {
        for key in keys {
            for header in root.values(forKey: key) {
                if let text = header["title"]?.text() { return text }
            }
        }
        return nil
    }

    private func bestThumbnail(in node: JSONValue) -> URL? {
        node.values(forKey: "thumbnails")
            .compactMap(\.arrayValue)
            .flatMap { $0 }
            .compactMap { $0["url"]?.stringValue }
            .compactMap(normalizedArtworkURL)
            .last
    }

    private func normalizedArtworkURL(_ raw: String) -> URL? {
        let value = raw.hasPrefix("//") ? "https:\(raw)" : raw
        guard var components = URLComponents(string: value) else { return nil }
        if components.scheme == nil { components.scheme = "https" }
        return components.url
    }

    private func continuation(in root: JSONValue) -> String? {
        root.values(forKey: "nextContinuationData")
            .compactMap { $0["continuation"]?.stringValue ?? $0["token"]?.stringValue }
            .first
    }

    private func duration(from text: String) -> TimeInterval? {
        let candidate = text.split(separator: " ").last(where: { $0.contains(":") }).map(String.init) ?? text
        let components = candidate.split(separator: ":").compactMap { Double($0) }
        guard components.count == 2 || components.count == 3 else { return nil }
        return components.reduce(0) { $0 * 60 + $1 }
    }

    private func subtitleParts(_ subtitle: String) -> [String] {
        subtitle
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && duration(from: $0) == nil && !["Song", "Video", "Album", "Single"].contains($0) }
    }

    private func slug(_ value: String) -> String {
        value.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }.reduce(into: "") { $0.append($1) }
    }

    private func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }
}
