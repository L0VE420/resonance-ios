# CI IPA guide

This workflow builds a signed `.ipa` of Resonance entirely on GitHub Actions. You do not need a Mac at runtime — only for the one-time export of the signing certificate and provisioning profile.

## One-time export (needs a Mac once)

```sh
# 1. Make sure the development team + bundle ID (e.g. dev.yourname.resonance)
#    are set in Xcode for the Resonance project.
# 2. In Keychain Access: My Certificates → Apple Development: <you> →
#    right-click → Export Items… → save as ResonanceCert.p12 with a password.
# 3. In Xcode → Settings → Accounts → your Apple ID → download the
#    "iOS App Development" provisioning profile (or fetch it from
#    https://developer.apple.com/account/resources/profiles/list).
# 4. Encode both for transport:
base64 -i ResonanceCert.p12          # copy output → RESONANCE_CERT_P12
base64 -i Resonance.mobileprovision  # copy output → RESONANCE_PROFILE
# 5. Find your 10-character Team ID under Apple Developer account membership.
```

## Required GitHub secrets

In your fork: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
| --- | --- |
| `RESONANCE_CERT_P12` | base64 of `ResonanceCert.p12` |
| `RESONANCE_CERT_PASSWORD` | the password you set when exporting the .p12 |
| `RESONANCE_PROFILE` | base64 of `Resonance.mobileprovision` |
| `RESONANCE_TEAM_ID` | 10-character team ID, e.g. `ABCDE12345` |
| `KEYCHAIN_PASSWORD` | any string (used only inside the runner) |

## Run the workflow

1. `git push` to the repository.
2. On GitHub: **Actions** tab → **Build IPA** → **Run workflow**.
3. When the job finishes, download the `Resonance-ipa` artifact. The `Resonance.ipa` is inside.

## Distribution modes

The committed `build/export/*.plist` files are templates you can reuse:

- `build/export/development.plist` – personal install on registered devices.
- `build/export/app-store-connect.plist` – upload to TestFlight / App Store.
- `build/export/ad-hoc.plist` – short-lived self-signed sideload.

To use a different mode locally on a Mac:

```sh
xcodebuild -exportArchive \
  -archivePath build/Resonance.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist build/export/<mode>.plist
```

## Troubleshooting

- **"Code signing is required"** in the archive step → the `RESONANCE_CERT_P12` / `RESONANCE_PROFILE` / `RESONANCE_TEAM_ID` secrets are missing or invalid. Re-export and re-paste.
- **Profile name mismatch** → open `Resonance.mobileprovision` and replace `PROVISIONING_PROFILE_SPECIFIER=Resonance` in `.github/workflows/ipa.yml` with the `Name` field.
- **`No Provisioning Profiles with a valid signing identity`** → the certificate imported into the temporary keychain is the wrong type. Use an *Apple Development* certificate, not a *Distribution* one.
- **App installs but crashes immediately** → check the device console in Xcode; the most common cause is `Info.plist` background-mode or transport-security mistakes.

## What the workflow does

1. Selects Xcode 16 on the macOS 14 runner.
2. Installs XcodeGen and regenerates the project from `project.yml`.
3. Imports the `.p12` into a temporary keychain, unlocks it, and sets the partition list so `codesign` may use it.
4. Writes the provisioning profile into `profiles/`.
5. Archives the app with manual signing + the provided team ID.
6. Writes `build/ExportOptions.plist` with `method=development`.
7. Calls `xcodebuild -exportArchive` to produce the `.ipa`.
8. Uploads `build/ipa/Resonance.ipa` as a downloadable artifact.
