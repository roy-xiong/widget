"""Copy canonical Flutter clock artwork without executing a local Flutter build."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
source = root / 'ios/ClockWidgets/Assets.xcassets'
resources = root / 'android/app/src/main/res'
target = resources / 'drawable-nodpi'
target.mkdir(parents=True, exist_ok=True)
for name, output in {
    'MotionDial': 'clock_dial', 'MotionHourHand': 'motion_hour', 'MotionMinuteHand': 'motion_minute',
    'MotionSecondHand': 'motion_second', 'MotionPin': 'motion_pin', 'TourbillonRim': 'tourbillon_rim',
    'TourbillonPositive': 'tourbillon_positive', 'TourbillonNegative': 'tourbillon_negative',
}.items():
    shutil.copyfile(source / f'{name}.imageset/{name}.png', target / f'{output}.png')
for name, size in [('clock_empty', 360), ('mechanism_empty', 81.0656)]:
    (resources / f'drawable/{name}.xml').write_text(f'<shape xmlns:android="http://schemas.android.com/apk/res/android"><size android:width="{size}dp" android:height="{size}dp"/><solid android:color="#00000000"/></shape>\n')
for name, drawable, size in [('clock_hour', 'motion_hour', 360), ('clock_minute', 'motion_minute', 360),
                             ('clock_second', 'motion_second', 360), ('mechanism_positive', 'tourbillon_positive', 81.0656),
                             ('mechanism_negative', 'tourbillon_negative', 81.0656)]:
    (resources / f'drawable/{name}.xml').write_text(f'<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:width="{size}dp" android:height="{size}dp" android:drawable="@drawable/{drawable}"/></layer-list>\n')
# Reuse the project icon; Android applies launcher masks independently.
icon = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'
if icon.exists():
    shutil.copyfile(icon, target / 'clock_app_icon.png')
print('Exported canonical clock layers and density-independent drawable bounds')
