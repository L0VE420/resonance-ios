import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var phase: HomeViewModel.Phase = .idle

    var body: some View {
        NavigationStack {
            AsyncStateView(phase: phase) { page in
                HomeScroll(page: page)
            }
            .navigationTitle("Resonance")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if case .loading = phase { return }
        phase = .loading
        do {
            phase = .loaded(try await container.catalogRepository.home())
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

private struct HomeScroll: View {
    let page: CatalogPage
    @EnvironmentObject private var container: AppContainer
    @State private var activeItem: CatalogItem?
    @State private var activeTrack: Track?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let hero = page.sections.first {
                    HeroShelf(section: hero, onPlay: { track, queue in
                        container.playback.play(track, in: queue)
                    })
                }
                ForEach(page.sections.dropFirst()) { section in
                    SectionGrid(title: section.title, items: section.items) { item in
                        activeItem = item
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(item: $activeItem) { item in
            CatalogItemDetailSheet(item: item) { track in
                activeTrack = track
            }
        }
        .sheet(item: $activeTrack) { track in
            NowPlayingView(initialTrack: track)
        }
    }
}
