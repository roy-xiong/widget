import 'package:desktop_clock/ui/clock_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('近似月相与 NASA 已知新月、上弦及满月的方向一致', () {
    // 独立日期来自 NASA 的 2024 年 UT 月相表；平均月模型允许少量相位偏差。
    final MoonPhase newMoon = MoonPhase.atUtc(DateTime.utc(2024, 4, 8, 18, 21));
    final MoonPhase firstQuarter = MoonPhase.atUtc(
      DateTime.utc(2024, 4, 15, 19, 13),
    );
    final MoonPhase fullMoon = MoonPhase.atUtc(
      DateTime.utc(2024, 4, 23, 23, 49),
    );
    final MoonPhase lastQuarter = MoonPhase.atUtc(
      DateTime.utc(2024, 5, 1, 11, 27),
    );
    expect(newMoon.illuminatedFraction, lessThan(.01));
    expect(firstQuarter.fraction, closeTo(.25, .03));
    expect(firstQuarter.waxing, isTrue);
    expect(firstQuarter.name, '上弦月');
    expect(fullMoon.illuminatedFraction, greaterThan(.99));
    expect(lastQuarter.fraction, closeTo(.75, .03));
    expect(lastQuarter.waxing, isFalse);
  });

  test('新月基准之前的日期和跨时区表达仍得到有效周期', () {
    final MoonPhase before = MoonPhase.atUtc(DateTime.utc(2000, 1, 1));
    expect(before.fraction, inInclusiveRange(0, 1));
    expect(before.illuminatedFraction, inInclusiveRange(0, 1));
    expect(
      MoonPhase.atUtc(DateTime.parse('2024-04-09T02:21:00+08:00')).fraction,
      MoonPhase.atUtc(DateTime.parse('2024-04-08T18:21:00Z')).fraction,
    );
  });

  testWidgets('切换显示时区跨日时更新星期日期，月相保持同一 UTC', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final DateTime utc = DateTime.utc(2026, 12, 31, 20, 5);
    Widget dial(DateTime display) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: ClockDial(displayTime: display, utcTime: utc),
        ),
      ),
    );
    await tester.pumpWidget(dial(utc));
    final ClockDialPainter oldPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('clock-dial-face')),
                )
                .painter!
            as ClockDialPainter;
    expect(find.bySemanticsLabel(RegExp('星期四，12月31日')), findsOneWidget);
    await tester.pumpWidget(dial(utc.add(const Duration(hours: 8))));
    final ClockDialPainter newPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('clock-dial-face')),
                )
                .painter!
            as ClockDialPainter;
    expect(find.bySemanticsLabel(RegExp('星期五，1月01日')), findsOneWidget);
    expect(newPainter.moon.fraction, oldPainter.moon.fraction);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  test('同一时分秒跨日重画日历，同一机械步进内不重复重画', () {
    final DateTime utc = DateTime.utc(2026, 10, 19, 10, 8, 30);
    final ClockDialPainter old = ClockDialPainter(
      time: utc,
      moon: MoonPhase.atUtc(utc),
    );
    final ClockDialPainter nextDay = ClockDialPainter(
      time: utc.add(const Duration(days: 1)),
      moon: MoonPhase.atUtc(utc),
    );
    final DateTime withinSecond = utc.add(const Duration(milliseconds: 100));
    expect(nextDay.shouldRepaint(old), isTrue);
    expect(
      ClockDialPainter(
        time: withinSecond,
        moon: MoonPhase.atUtc(withinSecond),
      ).shouldRepaint(old),
      isFalse,
    );
    final DateTime nextBeat = utc.add(const Duration(milliseconds: 125));
    expect(
      ClockDialPainter(
        time: nextBeat,
        moon: MoonPhase.atUtc(nextBeat),
      ).shouldRepaint(old),
      isTrue,
    );
  });

  test('一秒恰好八个离散位置，跨分钟沿用绝对时间网格', () {
    final DateTime base = DateTime.utc(2026, 10, 19, 10, 8, 59);
    final Set<int> positions = <int>{
      for (int ms = 0; ms < 1000; ms++)
        MechanicalTick.snap(
          base.add(Duration(milliseconds: ms)),
        ).microsecondsSinceEpoch,
    };
    expect(positions.length, 8);
    expect(
      MechanicalTick.snap(base.add(const Duration(milliseconds: 999))),
      base.add(const Duration(milliseconds: 875)),
    );
    expect(
      MechanicalTick.snap(base.add(const Duration(seconds: 1))),
      DateTime.utc(2026, 10, 19, 10, 9),
    );
  });

  testWidgets('指针按 125ms 步进且不重建静态表盘，切换时区保留已走时间', (WidgetTester tester) async {
    final DateTime utc = DateTime.utc(2026, 10, 19, 10, 8, 30);
    Widget dial(int offset) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: ClockDial(
            displayTime: utc.add(Duration(hours: offset)),
            utcTime: utc,
          ),
        ),
      ),
    );
    await tester.pumpWidget(dial(0));
    final CustomPaint face = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('clock-dial-face')),
    );
    final ClockHandsPainter hands =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('clock-dial-hands')),
                )
                .painter!
            as ClockHandsPainter;
    expect(hands.clock.value, utc);
    await tester.pump(const Duration(milliseconds: 124));
    expect(hands.clock.value, utc);
    await tester.pump(const Duration(milliseconds: 1));
    expect(hands.clock.value, utc.add(const Duration(milliseconds: 125)));
    await tester.pump(const Duration(milliseconds: 125));
    expect(hands.clock.value, utc.add(const Duration(milliseconds: 250)));
    expect(
      identical(
        tester.widget<CustomPaint>(
          find.byKey(const ValueKey<String>('clock-dial-face')),
        ),
        face,
      ),
      isTrue,
    );
    await tester.pumpWidget(dial(8));
    expect(
      hands.clock.value,
      utc.add(const Duration(hours: 8, milliseconds: 250)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
