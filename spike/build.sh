#!/bin/bash
# Builds the spike as a real .app bundle.
#
# A bare command-line tool does not work here: TCC will not show an
# audio-capture prompt for an unbundled binary, and an ungranted tap returns
# silence rather than an error, so the failure is invisible. The bundle gives
# TCC something to attribute the request to.
#
# Ad-hoc signing (-) changes identity on every rebuild, so macOS may re-prompt
# after each build. A real Developer ID makes the grant stick.
set -euo pipefail
cd "$(dirname "$0")"

# Signing identity. A real certificate (rather than ad-hoc "-") means macOS
# keeps the audio-capture permission across rebuilds instead of re-prompting
# every time, because TCC keys its decision on the signature.
#
# Override for a different certificate:
#   SIGN_IDENTITY="Developer ID Application: ..." ./build.sh
SIGN_IDENTITY="${SIGN_IDENTITY:-Apple Development: Quentin Vedrenne (K5FFJ2H2B8)}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/audiotap-spike"

APP="$PWD/audiotap-spike.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/audiotap-spike"

codesign --force --sign "$SIGN_IDENTITY" \
    --identifier com.quentinved.soundsmanager.spike "$APP"

echo "built: $APP"
echo
echo "  $APP/Contents/MacOS/audiotap-spike list"
echo "  $APP/Contents/MacOS/audiotap-spike tap <pid> --gain 0.05"
