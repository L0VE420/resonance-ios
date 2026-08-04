import SwiftUI

struct CatalogItemDetailSheet: View {
    let item: CatalogItem
    var onTrackSelected: (Track) -> Void
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var phase: AsyncState = .idle
    @State private var page: CatalogPage?

    var body: some View {
        NavigationStack {
            AsyncStateView(phase: phase) { page in
                DetailList(page: page, item: item, onTrackSelected: onTrackSelected)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        switch item {
        case .track(let track):
            container.playback.play(track)
            onTrackSelected(track)
            dismiss()
            return
        case .album(let album):
            phase = .loading
            do { phase = .loaded(try await container.catalogRepository.browse(id: album.browseID, fallbackTitle: album.title)) }
            catch { phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription) }
        case .artist(let artist):
            phase = .loading
            do { phase = .loaded(try await container.catalogRepository.browse(id: artist.browseID ?? artist.id, fallbackTitle: artist.name)) }
            catch { phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription) }
        case .playlist(let playlist):
            phase = .loading
            do { phase = .loaded(try await container.catalogRepository.browse(id: playlist.browseID, fallbackTitle: playlist.title)) }
            catch { phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription) }
        }
    }

    private typealias AsyncState = AsyncStateView<CatalogPage, DetailList>.Phase
}

private struct DetailList: View {
    let page: CatalogPage
    let item: CatalogItem
    let onTrackSelected: (Track) -> Void
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        List {
            Section {
                HeaderRow(item: item, trackCount: page.tracks.count)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Tracks") {
                ForEach(Array(page.tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        isPlaying: container.playback.currentTrack?.videoID == track.videoID,
                        primaryAction: {
                            container.playback.play(track, in: page.tracks)
                            onTrackSelected(track)
                        },
                        secondaryAction: {
                            container.libraryRepository.toggleLike(track)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct HeaderRow: View {
    let item: CatalogItem
    let trackCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArtworkView(url: item.artworkURL, size: 220, showsShadow: false)
                .frame(maxWidth: .infinity)
            Text(item.title)
                .font(.title2.weight(.bold))
            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .foregroundStyle(.secondary)
            }
            if trackCount > 0 {
                Text("\(trackCount) songs")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
}
