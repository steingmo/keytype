#!/bin/zsh
# Builds a signed, notarized, universal KeyType.app ready to share.
#
# One-time setup (see README):
#   1. A "Developer ID Application" certificate in your keychain.
#   2. Notary credentials: xcrun notarytool store-credentials keytype-notary \
#        --apple-id <your-apple-id> --team-id <TEAMID> --password <app-specific-password>
set -euo pipefail
cd "$(dirname "$0")"

IDENTITY="${KEYTYPE_IDENTITY:-Developer ID Application}"
PROFILE="${KEYTYPE_NOTARY_PROFILE:-keytype-notary}"
APP=build/KeyType.app
ZIP=build/KeyType.zip

echo "==> Building universal binary (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64

# Assemble and sign in a temp dir outside any iCloud-synced folder —
# the iCloud file provider re-stamps xattrs that break codesign.
STAGE=$(mktemp -d /tmp/keytype-release.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
STAGED_APP="$STAGE/KeyType.app"
STAGED_ZIP="$STAGE/KeyType.zip"

echo "==> Assembling ${STAGED_APP}"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp .build/apple/Products/Release/KeyType "$STAGED_APP/Contents/MacOS/KeyType"
cp Info.plist "$STAGED_APP/Contents/Info.plist"
cp AppIcon.icns "$STAGED_APP/Contents/Resources/AppIcon.icns"
xattr -cr "$STAGED_APP"

echo "==> Signing with '${IDENTITY}' (hardened runtime)"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$STAGED_APP"
codesign --verify --strict --verbose=2 "$STAGED_APP"

echo "==> Notarizing (profile: ${PROFILE})"
ditto -c -k --keepParent "$STAGED_APP" "$STAGED_ZIP"
xcrun notarytool submit "$STAGED_ZIP" --keychain-profile "$PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$STAGED_APP"

# Zip the stapled app and copy the results back into the project.
rm -f "$STAGED_ZIP"
ditto -c -k --keepParent "$STAGED_APP" "$STAGED_ZIP"
rm -rf "$APP" "$ZIP"
mkdir -p build
ditto "$STAGED_APP" "$APP"
cp "$STAGED_ZIP" "$ZIP"

echo ""
echo "Done. Share ${ZIP} — it opens on any Mac (macOS 13+) with no warnings."
spctl --assess --type execute --verbose "$APP" || true
