import Foundation
import SwiftData

@Model
final class SavedTrack {
    @Attribute(.unique) var videoID: String
    var title: String
    var artistText: String
    var albumTitle: String?
    var artworkURLString: String?
    var duration: Double?
    var createdAt: Date

    init(track: Track, createdAt: Date = .now) {
        videoID = track.videoID
        title = track.title
        artistText = track.artistText
        albumTitle = track.album?.title
        artworkURLString = track.artworkURL?.absoluteString
        duration = track.duration
        self.createdAt = createdAt
    }

    var track: Track {
        Track(
            videoID: videoID,
            title: title,
            artists: artistText.isEmpty ? [] : [Artist(id: artistText.lowercased(), name: artistText)],
            album: albumTitle.map { AlbumSummary(id: "local:\(videoID)", title: $0) },
            duration: duration,
            artworkURL: artworkURLString.flatMap(URL.init(string:))
        )
    }
}

@Model
final class LocalPlaylist {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        updatedAt = createdAt
    }
}

@Model
final class LocalPlaylistEntry {
    @Attribute(.unique) var id: UUID
    var playlistID: UUID
    var videoID: String
    var title: String
    var artistText: String
    var albumTitle: String?
    var artworkURLString: String?
    var duration: Double?
    var position: Int
    var addedAt: Date

    init(id: UUID = UUID(), playlistID: UUID, track: Track, position: Int, addedAt: Date = .now) {
        self.id = id
        self.playlistID = playlistID
        videoID = track.videoID
        title = track.title
        artistText = track.artistText
        albumTitle = track.album?.title
        artworkURLString = track.artworkURL?.absoluteString
        duration = track.duration
        self.position = position
        self.addedAt = addedAt
    }

    var track: Track {
        Track(
            videoID: videoID,
            title: title,
            artists: artistText.isEmpty ? [] : [Artist(id: artistText.lowercased(), name: artistText)],
            album: albumTitle.map { AlbumSummary(id: "local:\(videoID)", title: $0) },
            duration: duration,
            artworkURL: artworkURLString.flatMap(URL.init(string:))
        )
    }
}

@Model
final class PlayHistoryEntry {
    @Attribute(.unique) var id: UUID
    var videoID: String
    var title: String
    var artistText: String
    var artworkURLString: String?
    var playedAt: Date

    init(id: UUID = UUID(), track: Track, playedAt: Date = .now) {
        self.id = id
        videoID = track.videoID
        title = track.title
        artistText = track.artistText
        artworkURLString = track.artworkURL?.absoluteString
        self.playedAt = playedAt
    }
}

struct LocalPlaylistSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let updatedAt: Date
}
