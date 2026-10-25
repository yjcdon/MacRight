#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${MACRIGHT_ARCH:-$(uname -m)}"
APP="$ROOT/build/$ARCH/MacRight.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
NAME="MacRight-$VERSION-macos-$ARCH.zip"
codesign --verify --deep --strict "$APP"
mkdir -p "$ROOT/dist"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/$NAME"
cd "$ROOT/dist"
shasum -a 256 "$NAME" > "$NAME.sha256"
echo "$ROOT/dist/$NAME"
