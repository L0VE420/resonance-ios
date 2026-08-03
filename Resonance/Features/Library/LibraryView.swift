import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var likedTracks: [Track] = []
    @State private var playlists: [LocalPlaylistSummary] = []
    @State private var newPlaylistName: String = ""
    @State private var showCreate: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Liked songs") {
                    if likedTracks.isEmpty {
                        Text("Nothing liked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(likedTracks) { track in
                            TrackRow(
                                track: track,
                                isPlaying: container.playback.currentTrack?.videoID == track.videoID,
                                primaryAction: { container.playback.play(track, in: likedTracks) },
                                secondaryAction: { container.libraryRepository.toggleLike(track) }
                            )
                        }
                    }
                }
                Section("Playlists") {
                    Button {
                        showCreate = true
                    } label: {
                        Label("New playlist", systemImage: "plus.circle.fill")
                    }
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            LocalPlaylistView(playlistID: playlist.id)
                        } label: {
                            HStack {
                                ArtworkView(url: nil, size: 48, cornerRadius: 8, showsShadow: false)
                                VStack(alignment: .leading) {
                                    Text(playlist.title)
                                        .font(.body)
                                    Text(playlist.updatedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .alert("New playlist", isPresented: $showCreate) {
                TextField("Title", text: $newPlaylistName)
                Button("Create") {
                    let name = newPlaylistName
                    _ = container.libraryRepository.createPlaylist(named: name)
                    newPlaylistName = ""
                    refresh()
                }
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
            }
        }
        .task { refresh() }
        .onReceive(container.libraryRepository.objectWillChange) { _ in
            refresh()
        }
    }

    private func refresh() {
        likedTracks = container.libraryRepository.likedTracks()
        playlists = container.libraryRepository.playlists()
    }
}

struct LocalPlaylistView: View {
    let playlistID: UUID
    @EnvironmentObject private var container: AppContainer
    @State private var tracks: [Track] = []
    @State private var newName: String = ""
    @State private var showRename: Bool = false

    var body: some View {
        List {
            ForEach(tracks) { track in
                TrackRow(
                    track: track,
                    isPlaying: container.playback.currentTrack?.videoID == track.videoID,
                    primaryAction: { container.playback.play(track, in: tracks) },
                    secondaryAction: { container.libraryRepository.remove(track, from: playlistID) }
                )
            }
            if tracks.isEmpty {
                Text("This playlist is empty.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(container.libraryRepository.playlists().first(where: { $0.id == playlistID })?.title ?? "Playlist")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        newName = container.libraryRepository.playlists().first(where: { $0.id == playlistID })?.title ?? ""
                        showRename = true
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        container.libraryRepository.deletePlaylist(id: playlistID)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename playlist", isPresented: $showRename) {
            TextField("Title", text: $newName)
            Button("Save") {
                container.libraryRepository.renamePlaylist(id: playlistID, title: newName)
                refresh()
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
        .task { refresh() }
        .onReceive(container.libraryRepository.objectWillChange) { _ in refresh() }
    }

    private func refresh() {
        tracks = container.libraryRepository.tracks(in: playlistID)
    }
}
