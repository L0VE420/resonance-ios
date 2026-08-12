# Sideloading Resonance

This guide turns the Xcode project into an `.ipa` you can install on
any iPhone or iPad without going through the App Store. **You do not
need an Apple Developer account for the default path** — the IPA is
ad-hoc signed on a GitHub-hosted macOS runner.

## At-a-glance

| Mode                | Apple ID? | Where it builds           | Lasts on device | Installs via                  |
| ------------------- | --------- | ------------------------- | --------------- | ----------------------------- |
| **Ad-hoc (default)** | No        | GitHub Actions (free)     | Permanent*      | TrollStore / AppSync / AltStore / Sideloadly |
| Development         | Free      | GitHub Actions (free)     | 7 days, re-signed | AltStore / Sideloadly        |
| TestFlight          | Paid      | App Store Connect         | 90 days         | TestFlight app                |

\* Ad-hoc signatures are tied to the device's hardware identity and
expire when Apple decides to revoke them. In practice that's 1–3 years
for TrollStore-style installs; 90 days for re-signable flows.

> **Important:** Resonance uses YouTube Music's private InnerTube
> endpoints. Sideloading means you are personally responsible for your
> account — do not redistribute the IPA.

## No-Mac quickstart — ad-hoc IPA

This is the path that matches SoulStream's `build-ipa.yml`: zero Apple
ID, zero certificates, zero secrets.

### One-time: trigger the workflow

1. Open your fork on GitHub.
2. **Actions → Build IPA → Run workflow**.
3. Leave `signing` on the default `adhoc` and hit **Run**.
4. Wait ~5 minutes. When it finishes, the artifact
   `Resonance-adhoc.ipa` appears at the bottom of the run page —
   download it.

That's it. No certificates, no provisioning profiles, no team ID.

### How it works

The workflow (`/.github/workflows/sideload-ipa.yml`, `signing=adhoc`):

1. Generates `Resonance.xcodeproj` from `project.yml` with XcodeGen.
2. Picks the latest Xcode 16.x installed on the runner.
3. **Archives** with ad-hoc signing:
   ```
   CODE_SIGN_IDENTITY="-" \
   CODE_SIGNING_REQUIRED=YES \
   CODE_SIGNING_ALLOWED=YES \
   AD_HOC_CODE_SIGNING_ALLOWED=YES \
   CODE_SIGN_STYLE=Manual \
   PROVISIONING_PROFILE_SPECIFIER="" \
   DEVELOPMENT_TEAM="" \
   archive
   ```
   The `-` identity is "ad-hoc" — Apple's own term for an unsigned-by-
   Apple signature, which iOS accepts when paired with the install
   tool of your choice.
4. **Hand-packages the IPA** (the standard `xcodebuild -exportArchive`
   would refuse without a profile, so we bypass it):
   ```
   codesign --force --deep --sign - "$APP"
   cp -R "$APP" "$EXPORT/Payload/"
   ( cd "$EXPORT" && zip -qr Resonance.ipa Payload )
   ```
5. Uploads `Resonance-adhoc.ipa` as a workflow artifact.

### Install on your device

| Tool           | Jailbreak?  | What happens                                                      |
| -------------- | ----------- | ----------------------------------------------------------------- |
| **TrollStore** | iOS 15–16.5 | Permanent. The IPA's bundle ID is registered with `ldid`.         |
| **AppSync Unified** | Jailbroken | Installs the IPA into `/Applications/` via Apps Manager.      |
| **AltStore**   | No          | Re-signs with your Apple ID (free) and installs. 7-day cycle.    |
| **Sideloadly** | No          | Same as AltStore. Re-signs every 7 days.                         |

If you want a permanent install without a Mac and without re-signing,
TrollStore is the cleanest path. The device must be on a TrollStore-
supported iOS version (check the compatibility list — currently
iOS 15.0–16.5 with the `kfd`/`voucher_swap` exploits). For newer iOS,
use AltStore or Sideloadly and accept the 7-day re-sign loop.

## Mac quickstart — ad-hoc IPA (if you have a Mac)

If you have access to a Mac:

```sh
brew install xcodegen
git clone <repo> && cd "echoes ios"
./Scripts/build-sideload-ipa.sh
```

The script does the same thing the workflow does:

1. Generates the Xcode project.
2. Archives with `CODE_SIGN_IDENTITY="-"` and the other ad-hoc flags.
3. Re-signs with `codesign --force --deep --sign -`.
4. Zips the `Payload/` directory into `build/ResonanceExport/Resonance.ipa`.

Drop the resulting `.ipa` into TrollStore / AltStore / Sideloadly.

## Optional: Apple-ID-signed IPA

If you have a free Apple ID and want a cleaner install path:

1. Set GitHub secrets on your fork:
   - `APPLE_TEAM_ID` — your 10-character Team ID
   - `APPLE_BUNDLE_ID` — anything unique, e.g. `dev.yourname.resonance`
   - `APPLE_DEVELOPMENT_TEAM` — same as `APPLE_TEAM_ID` (legacy alias)
2. Run the workflow with `signing=development`.
3. The artifact is `Resonance-development.ipa` — install via AltStore
   / Sideloadly and authenticate with your Apple ID at install time.

This produces a personal-team signed IPA that lasts 7 days before
AltStore re-signs it. Same outcome as the ad-hoc path, but with a
slightly cleaner install experience on stock iOS.

## Troubleshooting

| Symptom                                                  | Cause / fix                                                                          |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Archive fails with `requires a provisioning profile`     | The workflow tried to fall back to automatic signing. Make sure `signing=adhoc`.    |
| `codesign` rejects the bundle because of entitlements    | An entitlements key requires a real profile. Leave `Config/Resonance.entitlements` empty (it is). |
| `xcodebuild: error: unable to find destination`          | The runner image hasn't installed Xcode 16. Re-run — the workflow self-installs via brew. |
| AltStore "Unable to find a valid signing identity"       | Your free Apple ID has never had a Development cert. Open Xcode once (any Mac) and build anything to your phone — Xcode mints the cert and AltStore picks it up next refresh. |
| TrollStore says "package not eligible"                   | The IPA's bundle ID isn't registered. TrollStore registers it automatically on first install; if it fails, try AltStore instead. |

For deeper coverage of CI workflows, see `Docs/CIPIPAGUIDE.md`.
