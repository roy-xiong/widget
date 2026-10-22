#!/bin/bash
# 与 BBK 保持一致，封装设备 Release 为可重签名 IPA，不读取 Apple 账号或证书。
set -euo pipefail
clock_app=build/ios/iphoneos/Runner.app
test -f "$clock_app/Info.plist"
test -d "$clock_app/Frameworks/Flutter.framework"
clock_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$clock_app/Info.plist")
lipo "$clock_app/$clock_executable" -verify_arch arm64
mkdir -p dist
clock_staging=$(mktemp -d "${TMPDIR:-/tmp}/widget-ios-XXXXXX")
trap 'rm -rf "$clock_staging"' EXIT
mkdir -p "$clock_staging/Payload"
ditto "$clock_app" "$clock_staging/Payload/Runner.app"
ditto -c -k --keepParent "$clock_staging/Payload" dist/DesktopClock-iOS-unsigned.ipa
unzip -tq dist/DesktopClock-iOS-unsigned.ipa
(cd dist && shasum -a 256 DesktopClock-iOS-unsigned.ipa > DesktopClock-iOS-unsigned.ipa.sha256)
