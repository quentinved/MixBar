#!/bin/bash
# Builds MixBar.app.
#
# The .app bundle is not optional: TCC will not show an audio-capture prompt for
# an unbundled binary, and an ungranted tap returns silence rather than an error,
# so the failure would be invisible.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"

# Ad-hoc ("-") by default so a fresh clone builds on any machine. A real
# certificate makes macOS keep the audio-capture permission across rebuilds,
# because TCC keys its decision on the signature:
#   SIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" ./build.sh
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# Universal, so one download runs on both architectures. Building for the host
# arch alone ships a DMG that is silently unopenable on every other kind of Mac.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/MixBar"

# Regenerate the icon so it can never drift from the generator.
swift "$ROOT/tools/make-icon.swift" "$ROOT/build/AppIcon.iconset" >/dev/null
iconutil -c icns "$ROOT/build/AppIcon.iconset" -o "$ROOT/build/AppIcon.icns"

APP="$ROOT/build/MixBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/MixBar"
cp "$ROOT/build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Notarization requires a *secure* timestamp from Apple's server. `--timestamp`
# is therefore mandatory for any Developer ID build; ad-hoc and development
# signing skip it, because it needs a network round-trip on every build and
# cannot be applied to an ad-hoc signature at all.
case "$SIGN_IDENTITY" in
    "Developer ID"*) TIMESTAMP=(--timestamp) ;;
    *)               TIMESTAMP=(--timestamp=none) ;;
esac

codesign --force --sign "$SIGN_IDENTITY" \
    --identifier com.quentinved.MixBar \
    --options runtime \
    "${TIMESTAMP[@]}" "$APP"
codesign --verify --verbose=1 "$APP"

echo "built: $APP (signed by: $SIGN_IDENTITY)"
