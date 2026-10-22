#!/bin/bash
# 在 GitHub macOS runner 上校验双架构、签名、DMG 和 ZIP；本地不自动构建。
set -euo pipefail
clock_app='build/macos/Build/Products/Release/桌面时钟.app'
test -d "$clock_app"
clock_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$clock_app/Contents/Info.plist")
lipo "$clock_app/Contents/MacOS/$clock_executable" -verify_arch x86_64 arm64
codesign --force --deep --sign - --entitlements macos/Runner/Release.entitlements "$clock_app"
codesign --verify --deep --strict "$clock_app"
mkdir -p dist
clock_staging=$(mktemp -d "${TMPDIR:-/tmp}/widget-macos-XXXXXX")
trap 'rm -rf "$clock_staging"' EXIT
ditto "$clock_app" "$clock_staging/桌面时钟.app"
ln -s /Applications "$clock_staging/Applications"
ditto -c -k --sequesterRsrc --keepParent "$clock_app" dist/DesktopClock-macOS-universal.zip
hdiutil create -volname '桌面时钟' -srcfolder "$clock_staging" -ov -format UDZO dist/DesktopClock-macOS-universal.dmg
hdiutil verify dist/DesktopClock-macOS-universal.dmg
unzip -tq dist/DesktopClock-macOS-universal.zip
(cd dist && shasum -a 256 DesktopClock-macOS-universal.dmg DesktopClock-macOS-universal.zip > DesktopClock-macOS.sha256)
