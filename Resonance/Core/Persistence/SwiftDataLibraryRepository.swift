import Combine
import Foundation
import SwiftData

@MainActor
protocol HistoryRecording: AnyObject {
    func recordPlayed(_ track: Track)
}

@MainActor
final class SwiftDataLibraryRepository: @preconcurrency ObservableObject, HistoryRecording {
    let objectWillChange = ObservableObjectPublisher()

    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func likedTracks() -> [Track] {
        let descriptor = FetchDescriptor<SavedTrack>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor))?.map(\.track) ?? []
    }

    func isLiked(_ videoID: String) -> Bool {
        var descriptor = FetchDescriptor<SavedTrack>(predicate: #Predicate { $0.videoID == videoID })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func toggleLike(_ track: Track) {
        if let existing = savedTrack(videoID: track.videoID) {
            context.delete(existing)
        } else {
            context.insert(SavedTrack(track: track))
        }
        persist()
    }

    func playlists() -> [LocalPlaylistSummary] {
        let descriptor = FetchDescriptor<LocalPlaylist>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor))?.map {
            LocalPlaylistSummary(id: $0.id, title: $0.title, updatedAt: $0.updatedAt)
        } ?? []
    }

    @discardableResult
    func createPlaylist(named rawTitle: String) -> LocalPlaylistSummary? {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let playlist = LocalPlaylist(title: title)
        context.insert(playlist)
        persist()
        return LocalPlaylistSummary(id: playlist.id, title: playlist.title, updatedAt: playlist.updatedAt)
    }

    func renamePlaylist(id: UUID, title rawTitle: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let playlist = playlist(id: id) else { return }
        playlist.title = title
        playlist.updatedAt = .now
        persist()
    }

    func deletePlaylist(id: UUID) {
        if let playlist = playlist(id: id) { context.delete(playlist) }
        for entry in playlistEntries(id: id) { context.delete(entry) }
        persist()
    }

    func tracks(in playlistID: UUID) -> [Track] {
        playlistEntries(id: playlistID).map(\.track)
    }

    func contains(_ track: Track, in playlistID: UUID) -> Bool {
        let videoID = track.videoID
        var descriptor = FetchDescriptor<LocalPlaylistEntry>(predicate: #Predicate {
            $0.playlistID == playlistID && $0.videoID == videoID
        })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func add(_ track: Track, to playlistID: UUID) {
        guard !contains(track, in: playlistID), let playlist = playlist(id: playlistID) else { return }
        let nextPosition = (playlistEntries(id: playlistID).map(\.position).max() ?? -1) + 1
        context.insert(LocalPlaylistEntry(playlistID: playlistID, track: track, position: nextPosition))
        playlist.updatedAt = .now
        persist()
    }

    func remove(_ track: Track, from playlistID: UUID) {
        let videoID = track.videoID
        let descriptor = FetchDescriptor<LocalPlaylistEntry>(predicate: #Predicate {
            $0.playlistID == playlistID && $0.videoID == videoID
        })
        for entry in (try? context.fetch(descriptor)) ?? [] { context.delete(entry) }
        normalizePositions(in: playlistID)
        playlist(id: playlistID)?.updatedAt = .now
        persist()
    }

    func recordPlayed(_ track: Track) {
        context.insert(PlayHistoryEntry(track: track))
        var descriptor = FetchDescriptor<PlayHistoryEntry>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        descriptor.fetchOffset = 200
        for oldEntry in (try? context.fetch(descriptor)) ?? [] { context.delete(oldEntry) }
        persist()
    }

    private func savedTrack(videoID: String) -> SavedTrack? {
        var descriptor = FetchDescriptor<SavedTrack>(predicate: #Predicate { $0.videoID == videoID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func playlist(id: UUID) -> LocalPlaylist? {
        var descriptor = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func playlistEntries(id: UUID) -> [LocalPlaylistEntry] {
        let descriptor = FetchDescriptor<LocalPlaylistEntry>(
            predicate: #Predicate { $0.playlistID == id },
            sortBy: [SortDescriptor(\.position)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func normalizePositions(in playlistID: UUID) {
        for (index, entry) in playlistEntries(id: playlistID).enumerated() {
            entry.position = index
        }
    }

    private func persist() {
        try? context.save()
        objectWillChange.send()
    }
}
