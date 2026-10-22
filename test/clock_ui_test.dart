import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_clock/domain/clock_settings.dart';
import 'package:desktop_clock/ui/clock_app.dart';
import 'package:desktop_clock/ui/clock_controller.dart';
import 'package:desktop_clock/ui/flip_tile.dart';
import 'package:desktop_clock/ui/manila_clock.dart';
import 'controller_test.dart'
    show MemoryPreferences, PendingWeather, FakeWindow;

void main() {
  testWidgets('玻璃区域报告缩放后的窗口坐标', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final List<Rect> regions = <Rect>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ManilaClock(
          time: DateTime(2026, 10, 22, 10, 8),
          city: '成都',
          weather: null,
          loading: false,
          error: null,
          refresh: () {},
          onGlassRect: regions.add,
        ),
      ),
    );
    await tester.pump();
    expect(regions, <Rect>[const Rect.fromLTWH(0, 32, 720, 428)]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final Size size in <Size>[
    const Size(266, 248),
    const Size(380, 355),
    const Size(844, 390),
  ]) {
    testWidgets('马尼拉与设置页适配 $size', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final MemoryPreferences preferences = MemoryPreferences();
      preferences.values['settings'] = <String, dynamic>{
        'style': ClockStyle.manila.name,
      };
      final ClockController controller = ClockController(
        preferences: preferences,
        weather: PendingWeather(),
        window: FakeWindow(),
        startTimers: false,
      );
      await tester.pumpWidget(ClockApp(controller: controller));
      await tester.pump();
      await tester.pump();
      expect(find.byType(FlipTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await controller.setShowingSettings(true);
      await tester.pump();
      expect(find.text('时钟设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('跨小时翻页和连续分钟变化正确收敛到最新数字', (WidgetTester tester) async {
    Widget tile(String value) => MaterialApp(
      home: Center(
        child: SizedBox(width: 159, height: 160, child: FlipTile(value: value)),
      ),
    );
    await tester.pumpWidget(tile('59'));
    await tester.pumpWidget(tile('00'));
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(tile('01'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('01'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
