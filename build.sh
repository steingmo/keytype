#!/bin/zsh
# Builds KeyType.app into ./build
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/KeyType.app

# Assemble and sign outside iCloud — the file provider re-stamps FinderInfo on
# anything under ~/Documents, and codesign refuses to sign a bundle carrying it.
STAGE=$(mktemp -d /tmp/keytype-build.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
STAGED_APP="$STAGE/KeyType.app"

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp .build/release/KeyType "$STAGED_APP/Contents/MacOS/KeyType"
cp Info.plist "$STAGED_APP/Contents/Info.plist"
cp AppIcon.icns "$STAGED_APP/Contents/Resources/AppIcon.icns"

# Embed the Sparkle auto-update framework.
mkdir -p "$STAGED_APP/Contents/Frameworks"
ditto .build/release/Sparkle.framework "$STAGED_APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$STAGED_APP/Contents/MacOS/KeyType"
xattr -cr "$STAGED_APP"

# Ad-hoc sign so the Accessibility grant survives rebuilds less flakily.
codesign --force --deep --sign - "$STAGED_APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$STAGED_APP"

rm -rf "$APP"
mkdir -p build
ditto "$STAGED_APP" "$APP"

echo "Built $APP"
