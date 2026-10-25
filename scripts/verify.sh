#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/verification"

xcrun swiftc -swift-version 6 -warnings-as-errors -O \
    "$ROOT/Shared/FileKind.swift" \
    "$ROOT/FinderExtension/FinderContextResolver.swift" \
    "$ROOT/FinderExtension/FileCreationService.swift" \
    "$ROOT/scripts/verify-core.swift" -o "$ROOT/build/verification/verify-core"
"$ROOT/build/verification/verify-core" "$ROOT"

xcrun swiftc -swift-version 6 -warnings-as-errors -O \
    "$ROOT/FinderExtension/DirectoryAccessStore.swift" \
    "$ROOT/FinderExtension/SystemActions.swift" \
    "$ROOT/FinderExtension/ClipboardAction.swift" \
    "$ROOT/scripts/verify-system.swift" -o "$ROOT/build/verification/verify-system"
"$ROOT/build/verification/verify-system"

plutil -lint "$ROOT/MacRightApp/Info.plist" "$ROOT/FinderExtension/Info.plist" \
    "$ROOT/FinderExtension/FinderExtension.entitlements" \
    "$ROOT/Resources/en.lproj/Localizable.strings" "$ROOT/Resources/zh-Hans.lproj/Localizable.strings"

# Verify the committed resources, without depending on files on the owner's Desktop.
cd "$ROOT"
/usr/bin/shasum -a 256 --check Resources/Templates/SHA256SUMS
for template in "$ROOT"/Resources/Templates/Office/*; do
    unzip -t "$template" | tail -1
done
