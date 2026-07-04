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

# Embed the Sparkle auto-update framework.
mkdir -p "$APP/Contents/Frameworks"
ditto .build/release/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/KeyType"

# Ad-hoc sign so the Accessibility grant survives rebuilds less flakily.
codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"

echo "Built $APP"
