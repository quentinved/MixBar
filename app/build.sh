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
#
# One slice at a time, then lipo: `swift build --arch arm64 --arch x86_64` looks
# like the obvious way and works on Swift 6.4, but on the 6.1 toolchain CI pins
# it cannot resolve a target's language mode and fails with an empty supported
# list. Per-arch builds take the same path on every toolchain.
# A separate scratch path per slice is what keeps them apart: with a shared one
# both builds resolve to the same bin path, the second overwrites the first, and
# lipo is handed the same architecture twice instead of failing loudly.
SLICES=()
for ARCH in arm64 x86_64; do
    SCRATCH=(--scratch-path ".build/slice-$ARCH")
    swift build -c release --arch "$ARCH" "${SCRATCH[@]}"
    SLICES+=("$(swift build -c release --arch "$ARCH" "${SCRATCH[@]}" --show-bin-path)/MixBar")
done

mkdir -p "$ROOT/build"
BIN="$ROOT/build/MixBar-universal"
lipo -create "${SLICES[@]}" -output "$BIN"

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
