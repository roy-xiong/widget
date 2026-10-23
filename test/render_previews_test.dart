import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_clock/domain/weather_snapshot.dart';
import 'package:desktop_clock/ui/clock_dial.dart'
    show MoonPhase, ClockDialPainter;
import 'package:desktop_clock/ui/manila_clock.dart';

/// 只在专用云端渲染任务执行，导出真正的 Flutter 画布，而不修改正式机械表盘。
void main() {
  const bool render = bool.fromEnvironment('RENDER_PREVIEWS');
  testWidgets('导出外观审阅图', skip: !render, (WidgetTester tester) async {
    await tester.runAsync(() async {
      Future<void> load(String family, List<String> candidates) async {
        for (final String path in candidates) {
          final File font = File(path);
          if (!font.existsSync()) continue;
          final FontLoader loader = FontLoader(family);
          loader.addFont(
            Future<ByteData>.value(
              ByteData.sublistView(await font.readAsBytes()),
            ),
          );
          await loader.load();
          return;
        }
        throw StateError('Missing render font $family');
      }

      await load('Helvetica Neue', <String>[
        '/System/Library/Fonts/HelveticaNeue.ttc',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
      ]);
      await load('PingFang SC', <String>[
        '/System/Library/Fonts/PingFang.ttc',
        '/System/Library/Fonts/STHeiti Light.ttc',
        '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
      ]);
      await load('serif', <String>[
        '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
        '/System/Library/Fonts/Times.ttc',
      ]);
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Future<void> capture(String name, Widget child, Size size) async {
      tester.view.physicalSize = size;
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Helvetica Neue'),
          home: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(key: key, child: child),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 2);
        final ByteData? data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) throw StateError('No PNG bytes');
        final File file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data.buffer.asUint8List());
        image.dispose();
      });
    }

    final DateTime instant = DateTime(2026, 10, 22, 10, 8, 38);
    final Widget dial = SizedBox(
      width: 850,
      height: 850,
      child: FittedBox(
        child: SizedBox(
          width: 360,
          height: 360,
          child: CustomPaint(
            painter: ClockDialPainter(
              time: instant,
              moon: MoonPhase.atUtc(instant.toUtc()),
            ),
          ),
        ),
      ),
    );
    await capture(
      'mechanical-concept',
      DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.6, -.7),
            radius: 1.5,
            colors: <Color>[Color(0xFF293843), Color(0xFF0C151C)],
          ),
        ),
        child: Center(child: dial),
      ),
      const Size(1000, 1000),
    );
    await capture(
      'mechanical-concept-transparent',
      Center(child: dial),
      const Size(900, 900),
    );
    await capture(
      'manila-glass',
      CustomPaint(
        painter: _Backdrop(),
        child: Center(
          child: SizedBox(
            width: 820,
            child: ManilaClock(
              time: instant,
              city: '成都',
              weather: WeatherSnapshot(
                cityKey: 'preview',
                temperature: 18,
                code: 2,
                isDay: true,
                fetchedAt: instant,
                high: 23,
                low: 15,
              ),
              loading: false,
              error: null,
              refresh: () {},
            ),
          ),
        ),
      ),
      const Size(1000, 760),
    );
    await capture(
      'widget-default-dial',
      Center(
        child: SizedBox(
          width: 360,
          height: 360,
          child: CustomPaint(
            painter: ClockDialPainter(
              time: instant,
              moon: MoonPhase.atUtc(instant.toUtc()),
              showHands: false,
              showComplications: false,
            ),
          ),
        ),
      ),
      const Size(360, 360),
    );
    await tester.runAsync(() async {
      final File source = File('build/previews/widget-default-dial.png');
      await source.copy(
        'ios/ClockWidgets/Assets.xcassets/DefaultDial.imageset/DefaultDial.png',
      );
    });
    await tester.pumpWidget(const SizedBox());
  });
}

/// 高对比渐变只用于审阅图背景，方便观察玻璃透光与模糊，正式时钟不绘制壁纸。
class _Backdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0D6593),
            Color(0xFF239A9C),
            Color(0xFFB3AE6A),
            Color(0xFFD18282),
            Color(0xFF51417D),
          ],
        ).createShader(rect),
    );
    for (int index = 0; index < 7; index++) {
      final Offset center = Offset(
        size.width * (.10 + index * .135),
        size.height * (index.isEven ? .72 : .31),
      );
      canvas.drawCircle(
        center,
        size.width * (.07 + index % 3 * .025),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 17),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Backdrop oldDelegate) => false;
}
