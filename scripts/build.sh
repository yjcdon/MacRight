#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${MACRIGHT_ARCH:-$(uname -m)}"
# Reuse a certificate identity across local rebuilds so macOS can retain privacy grants.
# Explicit "-" remains available for disposable ad-hoc builds.
if [ "${MACRIGHT_SIGN_IDENTITY+x}" = x ]; then
    SIGN_IDENTITY="$MACRIGHT_SIGN_IDENTITY"
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "MACRIGHT_SIGN_IDENTITY must name a signing identity or '-' for ad-hoc builds." >&2
        exit 1
    fi
else
    IDENTITIES="$(security find-identity -v -p codesigning)"
    CANDIDATES=()
    while read -r identity; do
        [ -z "$identity" ] || CANDIDATES+=("$identity")
    done < <(printf '%s\n' "$IDENTITIES" | awk '/"Apple Development:/ { print $2 }')
    if [ "${#CANDIDATES[@]}" -ne 1 ]; then
        echo "Set MACRIGHT_SIGN_IDENTITY to a certificate identity (or '-' for an ad-hoc build)." >&2
        exit 1
    fi
    SIGN_IDENTITY="${CANDIDATES[0]}"
fi
SDK="$(xcrun --show-sdk-path)"
BUILD="$ROOT/build/$ARCH"
APP="$BUILD/MacRight.app"
EXT="$APP/Contents/PlugIns/MacRightFinderExtension.appex"
LAUNCHER="$APP/Contents/Helpers/MacRightTerminalLauncher.app"
ICONSET="$BUILD/AppIcon.iconset"

case "$ARCH" in
    arm64|x86_64) ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Build all executables from repository sources; no Xcode-generated assets are required.
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" \
    "$EXT/Contents/MacOS" "$EXT/Contents/Resources/Templates" "$EXT/Contents/Resources/MenuIcons" \
    "$LAUNCHER/Contents/MacOS" "$LAUNCHER/Contents/Resources" "$ICONSET"
cp "$ROOT/MacRightApp/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/FinderExtension/Info.plist" "$EXT/Contents/Info.plist"
cp "$ROOT/TerminalLauncher/Info.plist" "$LAUNCHER/Contents/Info.plist"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$APP/Contents/Resources/"
cp "$ROOT/Resources/Licenses/Lucide-LICENSE" "$APP/Contents/Resources/"
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
xcrun swiftc "${SWIFT_FLAGS[@]}" -module-name MacRightTerminalLauncher \
    "$ROOT"/Shared/Terminal*.swift "$ROOT"/TerminalLauncher/*.swift -framework AppKit \
    -o "$LAUNCHER/Contents/MacOS/MacRightTerminalLauncher"

cp "$ROOT"/Resources/Templates/Office/* "$EXT/Contents/Resources/Templates/"
cp "$ROOT"/Resources/MenuIcons/*.png "$EXT/Contents/Resources/MenuIcons/"
for bundle in "$APP" "$EXT" "$LAUNCHER"; do
    for language in en zh-Hans; do
        mkdir -p "$bundle/Contents/Resources/$language.lproj"
        cp "$ROOT/Resources/$language.lproj/Localizable.strings" "$bundle/Contents/Resources/$language.lproj/"
    done
done

# Use the existing artwork at standard macOS icon sizes, without an asset compiler.
ICON="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ROOT/FinderExtension/FinderExtension.entitlements" "$EXT"
codesign --force --sign "$SIGN_IDENTITY" "$LAUNCHER"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
