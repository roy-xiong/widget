#!/bin/bash
# 与 BBK 保持一致，封装设备 Release 为可重签名 IPA，不读取 Apple 账号或证书。
set -euo pipefail
clock_app=build/ios/iphoneos/Runner.app
test -f "$clock_app/Info.plist"
test -d "$clock_app/Frameworks/Flutter.framework"
clock_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$clock_app/Info.plist")
lipo "$clock_app/$clock_executable" -verify_arch arm64
# App 与小组件分别校验，防止只构建 Runner 而漏掉扩展仍然上传空壳 IPA。
clock_extension="$clock_app/PlugIns/ClockWidgets.appex"
test -f "$clock_extension/ClockWidgets"
test -f "$clock_extension/Info.plist"
lipo "$clock_extension/ClockWidgets" -verify_arch arm64
clock_app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$clock_app/Info.plist")
clock_extension_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$clock_extension/Info.plist")
test "$clock_app_version" = "$clock_extension_version"
test "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$clock_extension/Info.plist")" = 'com.apple.widgetkit-extension'
mkdir -p dist
clock_staging=$(mktemp -d "${TMPDIR:-/tmp}/widget-ios-XXXXXX")
trap 'rm -rf "$clock_staging"' EXIT
mkdir -p "$clock_staging/Payload"
ditto "$clock_app" "$clock_staging/Payload/Runner.app"
ditto -c -k --keepParent "$clock_staging/Payload" dist/DesktopClock-iOS-unsigned.ipa
unzip -tq dist/DesktopClock-iOS-unsigned.ipa
(cd dist && shasum -a 256 DesktopClock-iOS-unsigned.ipa > DesktopClock-iOS-unsigned.ipa.sha256)
