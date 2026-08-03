# Porting notes

## Scope

The iOS MVP intentionally includes:

- Guest home browsing and search
- Album, artist, and playlist browsing
- Audio streaming, queue management, background playback, and system controls
- Local favorites and local playlists
- YouTube/LRCLIB synchronized lyrics

Deferred Android features include downloads, local-file scanning, Echo Find, podcasts, Listen Together, Spotify import, AI tools, Cast, advanced equalization/crossfade, account synchronization, analytics, and broad settings parity.

## Architecture

- **SwiftUI features** consume repository protocols and product-level models.
- **InnerTube networking** uses `URLSession`, guest client headers, bounded retries, and tolerant JSON traversal because YouTube response renderers vary frequently.
- **Streaming** resolves non-DRM audio formats from player responses. Signature and `n` transforms run in `JavaScriptCore` using solver resources pinned to the Android reference commit.
- **Playback** is centralized in one `@MainActor` controller around `AVPlayer`; lock-screen state is mirrored through MediaPlayer.
- **Persistence** uses SwiftData for liked tracks, playlists, ordered entries, and recent plays. It never stores YouTube account credentials.
- **Lyrics** use a provider registry with YouTube and LRCLIB fallbacks, normalized into one timestamped line model.

## Source mapping

| Android reference | iOS implementation |
| --- | --- |
| `innertube/.../InnerTube.kt`, `YouTube.kt` | `Resonance/Core/Networking/` |
| `app/.../playback/MusicService.kt` | `Resonance/Core/Playback/PlaybackController.swift` |
| `app/.../lyrics/` | `Resonance/Core/Lyrics/` |
| Room entities/DAO | `Resonance/Core/Persistence/` SwiftData models |
| Compose screens/view models | `Resonance/Features/` SwiftUI screens/models |

## macOS completion checklist

1. Install XcodeGen and generate `Resonance.xcodeproj`.
2. Run unit tests and an unsigned simulator build.
3. Exercise home, search, playback, queue, favorites, playlists, relaunch persistence, and synced lyrics.
4. Test a physical device for background audio, interruptions, headphone controls, artwork, and lock-screen seek/skip.
5. Replace the placeholder bundle ID, select a development team, create an archive, and upload to TestFlight.

Windows validation cannot replace these Apple-platform steps.
