import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    var initialTrack: Track? = nil

    @State private var lyrics: LyricsDocument?
    @State private var isLoadingLyrics: Bool = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let track = currentTrack {
                    ArtworkView(url: track.artworkURL, size: 320, cornerRadius: 28)
                    VStack(spacing: 4) {
                        Text(track.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(track.artistText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressBar(
                        elapsed: container.playback.elapsed,
                        duration: container.playback.duration
                    )
                    TransportControls()
                    lyricsView
                } else {
                    Text("Nothing is playing yet.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 120 { dismiss() }
                        else { withAnimation { dragOffset = 0 } }
                    }
            )
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadLyrics() }
        .onChange(of: container.playback.currentTrack) { _, _ in
            Task { await loadLyrics() }
        }
    }

    private var currentTrack: Track? { container.playback.currentTrack }

    @ViewBuilder
    private var lyricsView: some View {
        if let lyrics, !lyrics.lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lyrics • \(lyrics.source)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(lyrics.lines) { line in
                            Text(line.text.isEmpty ? "🎵" : line.text)
                                .font(.title3)
                                .foregroundStyle(isActive(line) ? ResonanceTheme.accent : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                }
            }
        } else if isLoadingLyrics {
            ProgressView()
        } else if currentTrack != nil {
            Text("No lyrics available for this track.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func loadLyrics() async {
        guard let track = currentTrack else { lyrics = nil; return }
        isLoadingLyrics = true
        lyrics = await container.lyricsService.lyrics(for: track)
        isLoadingLyrics = false
    }

    private func isActive(_ line: LyricsLine) -> Bool {
        let elapsed = container.playback.elapsed
        return line.startTime <= elapsed && (line.endTime ?? line.startTime + 4) >= elapsed
    }
}

private struct ProgressBar: View {
    let elapsed: TimeInterval
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(ResonanceTheme.accent)
            HStack {
                Text(format(elapsed))
                Spacer()
                Text(format(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    private func format(_ value: TimeInterval) -> String {
        guard value.isFinite, value >= 0 else { return "--:--" }
        let total = Int(value)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct TransportControls: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        HStack(spacing: 36) {
            Button { container.playback.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }
            .accessibilityLabel("Previous track")
            Button { container.playback.togglePlayPause() } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            Button { container.playback.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            .accessibilityLabel("Next track")
        }
        .tint(ResonanceTheme.accent)
    }

    private var isPlaying: Bool {
        if case .playing = container.playback.state { return true }
        return false
    }
}
