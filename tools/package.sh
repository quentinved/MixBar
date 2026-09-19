#!/bin/bash
# Produces the things people install from:
#   build/MixBar-<version>.dmg   drag-to-Applications disk image
#   build/MixBar-<version>.pkg   double-click installer (signed releases only)
#   build/mixbar.rb              Homebrew cask (needs a published URL + sha)
#
# For public release, use tools/release.sh, which signs with a Developer ID
# certificate and notarizes. Running this script directly produces an unsigned
# build suitable for local testing only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(plutil -extract CFBundleShortVersionString raw app/Info.plist)"
APP="$ROOT/build/MixBar.app"
STAGE="$ROOT/build/stage"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# A release build is one signed with a Developer ID Application certificate.
# Everything gated on this is about Gatekeeper on someone else's Mac.
IS_RELEASE=false
case "$SIGN_IDENTITY" in "Developer ID"*) IS_RELEASE=true ;; esac

# Installer packages are signed with a *Developer ID Installer* certificate,
# which is a different certificate from the Application one used for the .app.
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(security find-identity -v \
    | grep -o '"Developer ID Installer: [^"]*"' | head -1 | tr -d '"' || true)}"

app/build.sh >/dev/null
echo "app built ($VERSION)"

# --- disk image: the conventional way to ship a free Mac app ---
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/build/MixBar-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "MixBar" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"

# Signing the image itself (not just the app inside it) is what lets Gatekeeper
# vouch for the download before the user has opened it.
if [ "$IS_RELEASE" = true ]; then
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi
echo "dmg: $DMG"

# --- installer package, for people who expect Next-Next-Install ---
PKG="$ROOT/build/MixBar-$VERSION.pkg"
COMPONENT="$ROOT/build/component.pkg"
rm -f "$PKG" "$COMPONENT"

if [ "$IS_RELEASE" = true ] && [ -z "$INSTALLER_IDENTITY" ]; then
    # An unsigned .pkg is rejected by Gatekeeper on every machine but this one,
    # so shipping one is worse than shipping none at all.
    echo "pkg: SKIPPED — no 'Developer ID Installer' certificate in the keychain." >&2
    echo "     Create one alongside the Application certificate to ship a .pkg." >&2
else
    pkgbuild --quiet \
        --component "$APP" \
        --install-location /Applications \
        --identifier com.quentinved.MixBar \
        --version "$VERSION" \
        "$COMPONENT"
    if [ -n "$INSTALLER_IDENTITY" ]; then
        productbuild --quiet --package "$COMPONENT" \
            --sign "$INSTALLER_IDENTITY" --timestamp "$PKG"
        echo "pkg: $PKG (signed by: $INSTALLER_IDENTITY)"
    else
        productbuild --quiet --package "$COMPONENT" "$PKG"
        echo "pkg: $PKG (unsigned — local testing only)"
    fi
    rm -f "$COMPONENT"
fi

# --- Homebrew cask ---
SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
cat > "$ROOT/build/mixbar.rb" <<CASK
cask "mixbar" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/quentinved/MixBar/releases/download/v#{version}/MixBar-#{version}.dmg"
  name "MixBar"
  desc "Per-app volume mixer and output switcher for the menu bar"
  homepage "https://github.com/quentinved/MixBar"

  depends_on macos: ">= :sequoia"

  app "MixBar.app"

  zap trash: [
    "~/Library/Preferences/com.quentinved.MixBar.plist",
    "~/Library/Logs/MixBar.log",
  ]
end
CASK
echo "cask: $ROOT/build/mixbar.rb  (sha256 $SHA)"
rm -rf "$STAGE"
