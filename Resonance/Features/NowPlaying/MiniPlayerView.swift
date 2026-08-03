import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var container: AppContainer
    let onExpand: () -> Void

    var body: some View {
        if let track = container.playback.currentTrack {
            HStack(spacing: 12) {
                Button(action: onExpand) {
                    HStack(spacing: 12) {
                        ArtworkView(url: track.artworkURL, size: 44, cornerRadius: 8, showsShadow: false)
                        VStack(alignment: .leading) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(track.artistText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button { container.playback.togglePlayPause() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        }
    }

    private var isPlaying: Bool {
        if case .playing = container.playback.state { return true }
        return false
    }
}
