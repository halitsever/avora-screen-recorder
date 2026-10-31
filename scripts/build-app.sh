#!/usr/bin/env bash
# Builds build/Avora.app. Set SIGN_IDENTITY to sign with a real certificate;
# the default ad-hoc signature makes macOS ask for permissions again after each rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

app="build/Avora.app"
resources="$app/Contents/Resources"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$resources"
cp "$(swift build -c release --show-bin-path)/Avora" "$app/Contents/MacOS/Avora"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/Brand/avoraTemplate.png Resources/Brand/avoraTemplate@2x.png Resources/Brand/AvoraMark.png "$resources/"
cp Resources/Fonts/Sora.ttf "$resources/"
cp Resources/Fonts/OFL.txt "$resources/Sora-OFL.txt"

iconset="build/AppIcon.iconset"
rm -rf "$iconset"
mkdir -p "$iconset"
icon() { cp "Resources/Brand/AppIcon/avora-icon-$1.png" "$iconset/$2.png"; }
icon 16 icon_16x16
icon 32 icon_16x16@2x
icon 32 icon_32x32
icon 64 icon_32x32@2x
icon 128 icon_128x128
icon 256 icon_128x128@2x
icon 256 icon_256x256
icon 512 icon_256x256@2x
icon 512 icon_512x512
icon 1024 icon_512x512@2x
iconutil --convert icns --output "$resources/AppIcon.icns" "$iconset"
rm -rf "$iconset"

codesign --force --sign "${SIGN_IDENTITY:--}" "$app"

echo "$app"
