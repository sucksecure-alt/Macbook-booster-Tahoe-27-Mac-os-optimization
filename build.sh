#!/bin/bash
set -e
APP="Overdrive"
DIR="$APP.app"
DMG="Overdrive.dmg"

rm -rf "$DIR" "$DMG"
mkdir -p "$DIR/Contents/MacOS" "$DIR/Contents/Resources"

echo ""
echo "⚡️ Компиляция OVERDRIVE..."
for f in Sources/*.swift; do
    printf "   • %-22s %4d строк\n" "$(basename $f)" "$(wc -l < "$f")"
done
TOTAL=$(cat Sources/*.swift | wc -l)
echo "   Всего: $TOTAL строк"
echo ""

swiftc \
  Sources/Theme.swift \
  Sources/Models.swift \
  Sources/Services.swift \
  Sources/ViewModels.swift \
  Sources/Views.swift \
  Sources/App.swift \
  -o "$DIR/Contents/MacOS/$APP" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation \
  -framework Combine \
  -O \
  -parse-as-library

cp Info.plist "$DIR/Contents/Info.plist"
codesign --force --deep --sign - "$DIR" 2>/dev/null || true
xattr -cr "$DIR" 2>/dev/null || true

hdiutil create -srcfolder "$DIR" -volname "OVERDRIVE" -format UDZO -ov "$DMG" >/dev/null 2>&1

echo "╔══════════════════════════════════════════════╗"
echo "║   ⚡️  OVERDRIVE собран!                     ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  📦 $DIR"
echo "║  💿 $DMG"
echo "║  📝 $TOTAL строк"
echo "╠══════════════════════════════════════════════╣"
echo "║  🚀 open $DIR"
echo "╚══════════════════════════════════════════════╝"
