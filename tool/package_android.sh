#!/usr/bin/env bash
# 完整校验设备包及原生组件后交付；正式包不能携带 Debug 探针入口。
set -euo pipefail
clock_apk=build/app/outputs/flutter-apk/app-release.apk
test -s "$clock_apk"
mkdir -p dist
clock_tools=$(find "${ANDROID_HOME:-$ANDROID_SDK_ROOT}/build-tools" -name apksigner -type f | sort -V | tail -1)
test -n "$clock_tools"
"$clock_tools" verify --verbose "$clock_apk"
clock_aapt="$(dirname "$clock_tools")/aapt"
"$clock_aapt" dump badging "$clock_apk" > dist/android-package.txt
"$clock_aapt" dump xmltree "$clock_apk" AndroidManifest.xml > build/android-qa/release-manifest.txt
grep -q "com.xiongjian.widget" dist/android-package.txt
grep -q MechanicalWidgetProvider build/android-qa/release-manifest.txt
grep -q ManilaWidgetProvider build/android-qa/release-manifest.txt
if grep -q WidgetProbeActivity build/android-qa/release-manifest.txt; then exit 1; fi
cp "$clock_apk" dist/DesktopClock-Android.apk
(cd dist && sha256sum DesktopClock-Android.apk > DesktopClock-Android.apk.sha256)
python3 - <<'PY'
import shutil
shutil.make_archive('dist/DesktopClock-Android-QA', 'zip', 'build/android-qa')
PY
