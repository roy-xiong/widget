"""生成两端共用的原创时钟图标；仅依赖 Pillow，不读取外部图片或字体。"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
factor = 3
image = Image.new('RGBA', (1024 * factor, 1024 * factor))
draw = ImageDraw.Draw(image)


def box(bounds, radius, fill):
    draw.rounded_rectangle(tuple(v * factor for v in bounds), radius=radius * factor, fill=fill)


def circle(bounds, fill):
    draw.ellipse(tuple(v * factor for v in bounds), fill=fill)


def line(points, fill, width):
    draw.line([(x * factor, y * factor) for x, y in points], fill=fill, width=width * factor)


box((0, 0, 1024, 1024), 224, '#171d29')
circle((116, 116, 908, 908), '#d7c595')
circle((134, 134, 890, 890), '#425168')
circle((147, 147, 877, 877), '#ece7db')
circle((160, 160, 864, 864), '#151e30')
for index in range(60):
    angle = index * math.pi / 30 - math.pi / 2
    radius = 314 if index % 5 == 0 else 330
    line([(512 + radius * math.cos(angle), 512 + radius * math.sin(angle)),
          (512 + 346 * math.cos(angle), 512 + 346 * math.sin(angle))], '#ddd1ac', 10 if index % 5 == 0 else 4)
circle((410, 627, 614, 831), '#d7c595')
circle((451, 603, 635, 787), '#151e30')
line([(512, 525), (359, 393)], '#e2d3ae', 32)
line([(505, 523), (669, 313)], '#eee8d8', 20)
line([(459, 592), (658, 294)], '#729bbe', 5)
circle((486, 486, 538, 538), '#d7c595')
image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
for platform in ('macos', 'ios'):
    folder = root / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
    manifest = json.loads((folder / 'Contents.json').read_text())
    for item in manifest['images']:
        filename = item.get('filename')
        if not filename:
            continue
        points = float(item['size'].split('x')[0])
        pixels = round(points * float(item.get('scale', '1x').removesuffix('x')))
        icon = image.resize((pixels, pixels), Image.Resampling.LANCZOS)
        if platform == 'ios':
            # App Store 要求不透明图标，iOS 自行裁切圆角。
            background = Image.new('RGB', icon.size, '#171d29')
            background.paste(icon, mask=icon.getchannel('A'))
            icon = background
        icon.save(folder / filename)
print('Generated macOS and iOS clock icons')
