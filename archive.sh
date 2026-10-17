#!/bin/zsh
# Builds a sandboxed, hardened Snip.app signed for the Mac App Store.
# Does not replace /Applications/Snip.app. Pass --install to do that.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Snip
APP="build/Snip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Snip"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/Snip.icns "$APP/Contents/Resources/Snip.icns"
cp Resources/Snip_Mac_App_Store.provisionprofile "$APP/Contents/embedded.provisionprofile"
IDENTITY="Apple Distribution: Anup Aglawe (384UFAG6NB)"
codesign --force --options runtime --timestamp --entitlements Snip.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
productbuild --component "$APP" /Applications --sign "3rd Party Mac Developer Installer: Anup Aglawe (384UFAG6NB)" build/Snip.pkg
if [[ "${1:-}" == "--install" ]]; then
  pkill -x Snip 2>/dev/null || true
  rm -rf "/Applications/Snip.app"
  cp -R "$APP" "/Applications/Snip.app"
  open "/Applications/Snip.app"
fi
