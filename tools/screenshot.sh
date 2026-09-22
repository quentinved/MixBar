#!/bin/bash
# Photographs the popover in every layout, light and dark.
#
# The app poses itself (--pose, which implies --demo) and prints the window it
# opened; screencapture then takes that window by id, so nothing depends on
# where the window landed or what is in front of it. Screen Recording must be
# granted to whatever runs this — the terminal, not MixBar.
#
#   ./tools/screenshot.sh [outdir]      default: site/src/assets/shots
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/MixBar.app/Contents/MacOS/MixBar"
OUT="${1:-site/src/assets/shots}"
[ -x "$APP" ] || { echo "build it first: ./app/build.sh" >&2; exit 1; }
mkdir -p "$OUT"

shoot() {
    local layout="$1" suffix="$2" log
    log="$(mktemp)"

    "$APP" --pose "$layout" ${3:-} >"$log" 2>&1 &
    local pid=$!
    trap 'kill "$pid" 2>/dev/null || true' RETURN

    # The window id arrives once the panel has settled; without it screencapture
    # would race the first poll and photograph an empty popover.
    local id="" waited=0
    while [ -z "$id" ] && [ "$waited" -lt 100 ]; do
        id="$(sed -n 's/^window //p' "$log" | head -1)"
        [ -n "$id" ] || { sleep 0.1; waited=$((waited + 1)); }
    done
    [ -n "$id" ] || { echo "no window for $layout $suffix" >&2; return 1; }

    # -o drops the window's drop shadow: the page draws its own.
    screencapture -x -o -l"$id" "$OUT/$layout$suffix.png"
    echo "$OUT/$layout$suffix.png"
}

for layout in compact comfortable mixer; do
    shoot "$layout" ""
    shoot "$layout" "-dark" --dark
done
