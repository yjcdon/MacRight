#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${MACRIGHT_ARCH:-$(uname -m)}"
SIGN_IDENTITY="${MACRIGHT_SIGN_IDENTITY:--}"
SDK="$(xcrun --show-sdk-path)"
BUILD="$ROOT/build/$ARCH"
APP="$BUILD/MacRight.app"
EXT="$APP/Contents/PlugIns/MacRightFinderExtension.appex"
ICONSET="$BUILD/AppIcon.iconset"

case "$ARCH" in
    arm64|x86_64) ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Build both executables from repository sources; no Xcode-generated assets are required.
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" \
    "$EXT/Contents/MacOS" "$EXT/Contents/Resources/Templates" "$EXT/Contents/Resources/MenuIcons" "$ICONSET"
cp "$ROOT/MacRightApp/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/FinderExtension/Info.plist" "$EXT/Contents/Info.plist"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"
printf 'XPC!????' > "$EXT/Contents/PkgInfo"

SWIFT_FLAGS=(-sdk "$SDK" -target "$ARCH-apple-macos13.0" -swift-version 6 -warnings-as-errors -O -parse-as-library)
xcrun swiftc "${SWIFT_FLAGS[@]}" -module-name MacRight \
    "$ROOT"/MacRightApp/*.swift "$ROOT"/Shared/Terminal*.swift -framework SwiftUI -framework FinderSync \
    -o "$APP/Contents/MacOS/MacRight"
xcrun swiftc "${SWIFT_FLAGS[@]}" -module-name MacRightFinderExtension \
    -application-extension -emit-executable -Xlinker -e -Xlinker _NSExtensionMain \
    "$ROOT"/Shared/*.swift "$ROOT"/FinderExtension/*.swift \
    -framework AppKit -framework FinderSync \
    -o "$EXT/Contents/MacOS/MacRightFinderExtension"

cp "$ROOT"/Resources/Templates/Office/* "$EXT/Contents/Resources/Templates/"
cp "$ROOT"/Resources/MenuIcons/*.png "$EXT/Contents/Resources/MenuIcons/"
for language in en zh-Hans; do
    mkdir -p "$APP/Contents/Resources/$language.lproj" "$EXT/Contents/Resources/$language.lproj"
    cp "$ROOT/Resources/$language.lproj/Localizable.strings" "$APP/Contents/Resources/$language.lproj/"
    cp "$ROOT/Resources/$language.lproj/Localizable.strings" "$EXT/Contents/Resources/$language.lproj/"
done

# Use the existing artwork at standard macOS icon sizes, without an asset compiler.
ICON="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset/add (1) (1)-modified.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ROOT/FinderExtension/FinderExtension.entitlements" "$EXT"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
