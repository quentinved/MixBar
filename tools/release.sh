#!/bin/bash
# Signs, notarizes and staples a release build.
#
# Everything here needs a Developer ID Application certificate in the keychain,
# and a Developer ID *Installer* certificate as well if you want the .pkg (they
# are two different certificates; without the second one the .pkg is skipped).
# That certificate cannot be downloaded or copied from elsewhere: its private
# key is generated on this Mac. Create it with
#   Xcode -> Settings -> Accounts -> <team> -> Manage Certificates -> + -> Developer ID Application
#
# Credentials come from the environment so nothing secret lands in the repo.
# Two ways to authenticate notarization:
#
#   Local:  NOTARY_PROFILE   keychain profile from `notarytool store-credentials`
#                            (default: mixbar-notary)
#   CI:     NOTARY_KEY       path to the App Store Connect .p8 key file
#           NOTARY_KEY_ID    that key's Key ID
#           NOTARY_ISSUER    the Issuer ID (a UUID) from Users and Access > Keys
#
# The API-key route is the one to use in CI: it belongs to the team rather than
# to one person's Apple ID, and it does not break when someone's password
# changes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-mixbar-notary}"

fail() { printf '\n%s\n' "$1" >&2; exit 1; }

# --- preflight: fail early and say exactly what is missing ---
# `|| true`: with `set -o pipefail`, grep finding nothing would abort the
# script here, before the check below could explain what is missing.
IDENTITY="$(security find-identity -v -p codesigning \
    | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)"

[ -n "$IDENTITY" ] || fail "No Developer ID Application certificate in the keychain.
Create one: Xcode > Settings > Accounts > your team > Manage Certificates > + > Developer ID Application
(Requires a paid Apple Developer Program membership, and you must be the Account Holder.)"

if [ -n "${NOTARY_KEY:-}" ]; then
    [ -f "$NOTARY_KEY" ] || fail "NOTARY_KEY is set but '$NOTARY_KEY' does not exist."
    [ -n "${NOTARY_KEY_ID:-}" ] || fail "NOTARY_KEY is set but NOTARY_KEY_ID is not."
    [ -n "${NOTARY_ISSUER:-}" ] || fail "NOTARY_KEY is set but NOTARY_ISSUER is not."
    NOTARY_AUTH=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
    echo "notarization: App Store Connect API key $NOTARY_KEY_ID"
else
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || fail \
"No notarization credentials found.

For local use, create an app-specific password at appleid.apple.com, then:
  xcrun notarytool store-credentials $NOTARY_PROFILE \\
      --apple-id <your-apple-id> --team-id <your-team-id> --password <app-specific-password>
Profile names must be at least 3 characters.

For CI, set NOTARY_KEY, NOTARY_KEY_ID and NOTARY_ISSUER instead."
    NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
    echo "notarization: keychain profile $NOTARY_PROFILE"
fi

echo "signing identity: $IDENTITY"

# --- build and package with the real certificate ---
SIGN_IDENTITY="$IDENTITY" tools/package.sh

VERSION="$(plutil -extract CFBundleShortVersionString raw app/Info.plist)"
DMG="$ROOT/build/MixBar-$VERSION.dmg"
[ -f "$DMG" ] || fail "package.sh did not produce $DMG"

# --- notarize: Apple scans the upload, so this takes a few minutes ---
# Every artifact a user can download has to go through this separately: a
# notarized DMG says nothing about the PKG sitting next to it on the release
# page. Stapling then attaches the ticket to the file, so Gatekeeper accepts it
# even on a machine that is offline when the user first opens it.
PKG="$ROOT/build/MixBar-$VERSION.pkg"

for ARTIFACT in "$DMG" "$PKG"; do
    [ -f "$ARTIFACT" ] || continue
    echo "submitting $(basename "$ARTIFACT") for notarization…"
    xcrun notarytool submit "$ARTIFACT" "${NOTARY_AUTH[@]}" --wait
    xcrun stapler staple "$ARTIFACT"
    xcrun stapler validate "$ARTIFACT"
done

# --- what Gatekeeper will actually say on someone else's Mac ---
echo
echo "Gatekeeper assessment:"
MNT="$(hdiutil attach "$DMG" -nobrowse -readonly | tail -1 | sed 's/^.*\(\/Volumes\/.*\)$/\1/')"
spctl --assess --type execute --verbose=2 "$MNT/MixBar.app" || true
hdiutil detach "$MNT" -quiet

# Stapling rewrites the DMG, so the checksum package.sh wrote into the cask is
# already stale by now. Correct it in place: a cask whose sha256 does not match
# the published file fails for every user with a checksum mismatch.
CASK="$ROOT/build/mixbar.rb"
SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
if [ -f "$CASK" ]; then
    /usr/bin/sed -i '' -E "s/sha256 \"[a-f0-9]{64}\"/sha256 \"$SHA\"/" "$CASK"
    echo "cask sha256 updated: $SHA"
fi
echo "release ready: $DMG"
