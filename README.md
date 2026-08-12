# Resonance

Resonance is a native SwiftUI proof-of-concept port of the core Echo Music experience for iOS. The first milestone provides guest YouTube Music browsing and search, streaming playback, a queue, local favorites and playlists, synchronized lyrics, background audio, and lock-screen controls.

> **Status:** source-first MVP. This Windows machine cannot compile Apple frameworks or produce an IPA. Generate and build the project on macOS with Xcode 16 or later.

## Reference baseline

- Android reference: [EchoMusicApp/Echo-Music](https://github.com/EchoMusicApp/Echo-Music)
- Pinned commit: `35ad20446c6947900b57a20669a92281e6bbb73b`
- Reference APK: Echo Music `5.2.85`
- APK SHA-256: `C3C56F68149F8580B895C42CD8355973421C10E38288620D7317590704EF85FF`
- License: GPL-3.0; see `LICENSE` and `NOTICE.md`

The temporary name, icon, and bundle ID are placeholders and do not assert rights to Echo branding.

## Requirements

- macOS with Xcode 16+
- XcodeGen (`brew install xcodegen`)
- iOS 17+ simulator or device
- An Apple Developer team for device/TestFlight signing

## Build

```sh
xcodegen generate
xcodebuild -project Resonance.xcodeproj \
  -scheme Resonance \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Run tests with:

```sh
xcodebuild -project Resonance.xcodeproj \
  -scheme Resonance \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Before device distribution, replace `com.example.resonance` and the empty development team in `project.yml`.

## Important limitations

Resonance uses YouTube Music's private InnerTube endpoints and a player-script resolver. These interfaces are undocumented, may change without notice, and may be subject to YouTube terms and content restrictions. The app does not bypass DRM. This MVP is intended for authorized personal testing through local signing or TestFlight, not as an App Store-ready product.

See `Docs/PORTING.md` for architecture, scope, and macOS verification steps.

## Sideloading without a Mac

You can build an `.ipa` entirely on GitHub Actions — no Apple Developer
account required. The `Build IPA` workflow (Actions tab → Run workflow)
defaults to **ad-hoc signing**, which produces an IPA installable on
jailbroken devices via TrollStore / AppSync, and on stock iOS via
AltStore / Sideloadly (which re-sign with your free Apple ID
on-device).

See `Docs/SIDELOAD.md` for the full guide.

## Self-healing build loop

Two layers:

- **Local** — `Scripts/ci-watch.ps1` / `Scripts/ci-watch.sh` trigger
  the workflow, poll until done, download the IPA on success, and dump
  the failing log on failure. Paste the dump into Claude and the loop
  repeats.
- **Fully automatic** — `.github/workflows/auto-fix.yml` runs Claude
  Code whenever `Build IPA` (or the simulator / unit-test workflows)
  fails. Requires an `ANTHROPIC_API_KEY` secret. Opens a PR with the
  proposed fix.

See `Docs/SIDELOAD.md#self-healing-loop` for details.
