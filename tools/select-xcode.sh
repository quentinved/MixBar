#!/bin/bash
# Selects the newest Xcode whose SDK is not ahead of the running macOS.
#
# A newer SDK than the OS builds fine and then fails to load: the Swift
# overlays it links against resolve to /usr/lib/swift at run time, which is the
# older copy shipped with the system. That cost the test job every run it ever
# made — everything compiled, then the bundle would not dlopen.
set -euo pipefail

OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
for CANDIDATE in $(ls -d /Applications/Xcode*.app | sort -Vr); do
    SDK="$(DEVELOPER_DIR="$CANDIDATE/Contents/Developer" \
        xcrun --sdk macosx --show-sdk-version 2>/dev/null)" || continue
    [ "${SDK%%.*}" -le "$OS_MAJOR" ] || continue

    echo "macOS $OS_MAJOR, using $CANDIDATE (SDK $SDK)"
    sudo xcode-select -s "$CANDIDATE"
    swift --version
    exit 0
done

echo "no Xcode on this machine has an SDK at or below macOS $OS_MAJOR" >&2
exit 1
