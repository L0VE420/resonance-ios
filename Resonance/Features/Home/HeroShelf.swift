import SwiftUI

struct HeroShelf: View {
    let section: BrowseSection
    let onPlay: (Track, [Track]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title2.weight(.bold))
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(section.items.prefix(10))) { item in
                        Button {
                            if case .track(let track) = item {
                                onPlay(track, section.items.compactMap { if case .track(let t) = $0 { return t } else { return nil } })
                            }
                        } label: {
                            CatalogCardView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
