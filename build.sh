#!/bin/zsh
# Builds KeyType.app into ./build
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/KeyType.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KeyType "$APP/Contents/MacOS/KeyType"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so the Accessibility grant survives rebuilds less flakily.
codesign --force --sign - "$APP"

echo "Built $APP"
