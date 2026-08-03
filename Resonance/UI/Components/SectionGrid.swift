import SwiftUI

struct SectionGrid: View {
    let title: String
    let items: [CatalogItem]
    let onSelect: (CatalogItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    Button(action: { onSelect(item) }) {
                        CatalogCardView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CatalogCardView: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(url: item.artworkURL, size: 160, cornerRadius: 16)
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
