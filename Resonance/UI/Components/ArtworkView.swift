import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 64
    var cornerRadius: CGFloat = 12
    var showsShadow: Bool = true

    var body: some View {
        ZStack {
            ResonanceTheme.artworkPlaceholder
            if let url {
                AsyncImage(url: url, transaction: .init(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .empty:
                        Color.clear
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        ResonanceTheme.artworkPlaceholder
                    @unknown default:
                        ResonanceTheme.artworkPlaceholder
                    }
                }
            } else {
                ResonanceTheme.artworkPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(showsShadow ? 0.18 : 0), radius: size / 12, x: 0, y: size / 24)
    }
}
