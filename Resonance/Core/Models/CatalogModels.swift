import Foundation

struct Artist: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let browseID: String?
    let artworkURL: URL?

    init(id: String, name: String, browseID: String? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.name = name
        self.browseID = browseID
        self.artworkURL = artworkURL
    }
}

struct AlbumSummary: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let browseID: String?
}

struct Track: Identifiable, Hashable, Codable, Sendable {
    var id: String { videoID }

    let videoID: String
    let title: String
    let artists: [Artist]
    let album: AlbumSummary?
    let duration: TimeInterval?
    let artworkURL: URL?
    let explicit: Bool

    init(
        videoID: String,
        title: String,
        artists: [Artist] = [],
        album: AlbumSummary? = nil,
        duration: TimeInterval? = nil,
        artworkURL: URL? = nil,
        explicit: Bool = false
    ) {
        self.videoID = videoID
        self.title = title
        self.artists = artists
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.explicit = explicit
    }

    var artistText: String {
        artists.map(\.name).joined(separator: ", ")
    }
}

struct Album: Identifiable, Hashable, Codable, Sendable {
    var id: String { browseID }

    let browseID: String
    let title: String
    let artists: [Artist]
    let artworkURL: URL?
    let year: String?
}

struct Playlist: Identifiable, Hashable, Codable, Sendable {
    var id: String { browseID }

    let browseID: String
    let title: String
    let owner: String?
    let artworkURL: URL?
    let trackCountText: String?
}

enum CatalogItem: Identifiable, Hashable, Sendable {
    case track(Track)
    case album(Album)
    case artist(Artist)
    case playlist(Playlist)

    var id: String {
        switch self {
        case .track(let track): "track:\(track.id)"
        case .album(let album): "album:\(album.id)"
        case .artist(let artist): "artist:\(artist.id)"
        case .playlist(let playlist): "playlist:\(playlist.id)"
        }
    }

    var title: String {
        switch self {
        case .track(let track): track.title
        case .album(let album): album.title
        case .artist(let artist): artist.name
        case .playlist(let playlist): playlist.title
        }
    }

    var subtitle: String {
        switch self {
        case .track(let track): track.artistText
        case .album(let album): album.artists.map(\.name).joined(separator: ", ")
        case .artist: "Artist"
        case .playlist(let playlist): playlist.owner ?? playlist.trackCountText ?? "Playlist"
        }
    }

    var artworkURL: URL? {
        switch self {
        case .track(let track): track.artworkURL
        case .album(let album): album.artworkURL
        case .artist(let artist): artist.artworkURL
        case .playlist(let playlist): playlist.artworkURL
        }
    }
}

struct BrowseSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [CatalogItem]
}

struct CatalogPage: Hashable, Sendable {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let sections: [BrowseSection]
    let continuation: String?

    var tracks: [Track] {
        sections.flatMap(\.items).compactMap {
            if case .track(let track) = $0 { return track }
            return nil
        }
    }
}
