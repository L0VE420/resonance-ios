#!/usr/bin/env bash
# Build Resonance.ipa locally on a Mac (no Apple Developer account required).
#
# Ad-hoc signed (`-` identity) — installable on jailbroken iOS devices
# via TrollStore / AppSync, and on stock iOS via AltStore / Sideloadly
# (they re-sign with your free Apple ID on-device).
#
# For a real Apple-ID-signed IPA run the GitHub Actions workflow
# (.github/workflows/sideload-ipa.yml) with signing=development after
# setting APPLE_DEVELOPMENT_TEAM and APPLE_BUNDLE_ID secrets.
#
# Pattern lifted from SoulStream's scripts/build-local.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▶ Checking for Xcode…"
if ! command -v xcodebuild &>/dev/null; then
    echo "✗ xcodebuild not found. Install Xcode 16+ from the App Store."
    exit 1
fi
xcodebuild -version

echo "▶ Checking for XcodeGen…"
if ! command -v xcodegen &>/dev/null; then
    echo "▶ Installing XcodeGen via Homebrew…"
    brew install xcodegen
fi
xcodegen --version

echo "▶ Generating Xcode project…"
xcodegen generate

SCHEME=Resonance
ARCHIVE=build/Resonance.xcarchive
EXPORT=build/ResonanceExport
mkdir -p build

echo "▶ Archiving (ad-hoc)…"
xcodebuild \
    -project Resonance.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_STYLE=Manual \
    archive

echo "▶ Packaging ad-hoc IPA…"
APP="$ARCHIVE/Products/Applications/$SCHEME.app"
codesign --force --deep --sign - "$APP"
mkdir -p "$EXPORT/Payload"
cp -R "$APP" "$EXPORT/Payload/"
( cd "$EXPORT" && zip -qr Resonance.ipa Payload )

echo ""
echo "✓ Built: $EXPORT/Resonance.ipa"
echo ""
echo "Next steps:"
echo "  • Jailbroken device   : drop into TrollStore or install via AppSync."
echo "  • Sideloadly/AltStore : drag the .ipa onto the connected device."
echo "  • To sign with your Apple ID instead, see the GitHub Actions"
echo "    workflow (.github/workflows/sideload-ipa.yml) and run it with"
echo "    signing=development after setting APPLE_DEVELOPMENT_TEAM and"
echo "    APPLE_BUNDLE_ID secrets."
