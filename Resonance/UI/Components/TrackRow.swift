import SwiftUI

struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    var showsArtwork: Bool = true
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        Button(action: primaryAction) {
            HStack(spacing: 12) {
                if showsArtwork {
                    ArtworkView(url: track.artworkURL, size: 48)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body.weight(isPlaying ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(isPlaying ? ResonanceTheme.accent : .primary)
                    Text(track.artistText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: secondaryAction) {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options for \(track.title)")
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
