import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var playback: PlaybackController
    @State private var selection: Tab = .home
    @State private var nowPlayingVisible = false

    enum Tab: Hashable { case home, search, library }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(Tab.search)
                LibraryView()
                    .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                    .tag(Tab.library)
            }
            if playback.currentTrack != nil {
                MiniPlayerView(onExpand: { nowPlayingVisible = true })
                    .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $nowPlayingVisible) {
            NowPlayingView()
        }
        .background(ResonanceTheme.pageBackground.ignoresSafeArea())
    }
}
