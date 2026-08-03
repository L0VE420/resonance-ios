import Foundation
import SwiftData

@MainActor
final class AppContainer: ObservableObject {
    let modelContainer: ModelContainer
    let catalogRepository: any CatalogRepository
    let libraryRepository: SwiftDataLibraryRepository
    let lyricsService: LyricsService
    let playback: PlaybackController

    init(inMemory: Bool = false) {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            modelContainer = try ModelContainer(
                for: SavedTrack.self,
                LocalPlaylist.self,
                LocalPlaylistEntry.self,
                PlayHistoryEntry.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to create the local music library: \(error.localizedDescription)")
        }

        let http = HTTPClient()
        let innerTube = InnerTubeClient(http: http)
        catalogRepository = LiveCatalogRepository(client: innerTube)
        libraryRepository = SwiftDataLibraryRepository(modelContainer: modelContainer)
        lyricsService = LyricsService(
            providers: [
                YouTubeLyricsProvider(client: innerTube),
                LRCLIBLyricsProvider(http: http)
            ]
        )

        let streamResolver = YouTubeStreamResolver(client: innerTube, http: http)
        playback = PlaybackController(
            resolver: streamResolver,
            historyRecorder: libraryRepository
        )
    }
}
