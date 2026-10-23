import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../domain/clock_settings.dart';

/// 供表盘显示的近似月相，不参与授时编码。
///
/// 以 NASA 月相表的 2024-04-08 18:21 UTC 新月为基准，按平均朔望月
/// 29.530589 天推算；不包含轨道摄动修正，适合表盘盈亏示意。
/// https://eclipse.gsfc.nasa.gov/phase/phase2001gmt.html
/// https://eclipse.gsfc.nasa.gov/LEsaros/LEperiodicity.html
class MoonPhase {
  const MoonPhase._(this.fraction, this.utcMinute);

  static const double synodicDays = 29.530589;
  static final DateTime _newMoon = DateTime.utc(2024, 4, 8, 18, 21);

  /// 一个周期的进度：0 新月、0.25 上弦、0.5 满月、0.75 下弦。
  final double fraction;
  final int utcMinute;

  factory MoonPhase.atUtc(DateTime instant) {
    final DateTime utc = instant.toUtc();
    final int minute =
        utc.microsecondsSinceEpoch ~/ Duration.microsecondsPerMinute;
    final double cycles =
        utc.difference(_newMoon).inMicroseconds /
        Duration.microsecondsPerDay /
        synodicDays;
    return MoonPhase._(cycles - cycles.floorToDouble(), minute);
  }

  double get illuminatedFraction => (1 - math.cos(2 * math.pi * fraction)) / 2;
  bool get waxing => fraction < .5;
  String get name => const <String>[
    '新月',
    '娥眉月',
    '上弦月',
    '盈凸月',
    '满月',
    '亏凸月',
    '下弦月',
    '残月',
  ][(fraction * 8 + .5).floor() % 8];
}

/// 从正式画笔导出的独立透明图层，小组件直接复用，不再另画近似指针。
enum HandArtwork { hour, minute, second, pin }

/// 固定金属框与活动机芯分开，避免旋转整张截图导致外框也跟着转动。
enum TourbillonArtwork { rim, mechanism }

/// 常见 28,800 次/小时机械机芯的显示节奏；只改变视觉，不改变授时音频。
abstract final class MechanicalTick {
  static const int beatsPerSecond = 8;
  static const int microsecondsPerBeat =
      Duration.microsecondsPerSecond ~/ beatsPerSecond;

  /// 按绝对时间落在 125 ms 网格上，不累加角度，跨秒、跨分时不会累计漂移。
  static DateTime snap(DateTime time) {
    final int micros = time.microsecondsSinceEpoch;
    return DateTime.fromMicrosecondsSinceEpoch(
      micros - micros % microsecondsPerBeat,
      isUtc: time.isUtc,
    );
  }
}

/// 日历遵循所选显示时区，月相使用真实 UTC；秒针由独立的八步节奏驱动。
class ClockDial extends StatefulWidget {
  const ClockDial({
    super.key,
    required this.displayTime,
    required this.utcTime,
    this.moonScale = 1,
    this.calendarScale = 1,
    this.romanScale = 1,
  });
  final DateTime displayTime;
  final DateTime utcTime;
  final double moonScale, calendarScale, romanScale;
  static const List<String> weekdays = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  @override
  State<ClockDial> createState() => _ClockDialState();
}

/// Ticker 只唤醒指针画布，不 setState 整个主页；离屏时跟随 TickerMode 静默。
class _ClockDialState extends State<ClockDial>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<DateTime> _handTime;
  late DateTime _displayAnchor;
  Duration _lastElapsed = Duration.zero;
  Duration _anchorElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _displayAnchor = widget.displayTime;
    _handTime = ValueNotifier<DateTime>(MechanicalTick.snap(_displayAnchor));
    _ticker = createTicker((Duration elapsed) {
      _lastElapsed = elapsed;
      _handTime.value = MechanicalTick.snap(
        _displayAnchor.add(elapsed - _anchorElapsed),
      );
    })..start();
  }

  @override
  void didUpdateWidget(covariant ClockDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.utcTime != oldWidget.utcTime) {
      // 接入主页当前的校准时间，视觉插值不替代真正的 UTC 时钟。
      _displayAnchor = widget.displayTime;
      _anchorElapsed = _lastElapsed;
    } else if (widget.displayTime != oldWidget.displayTime) {
      // 仅切换显示时区时保留已走过的小步进，避免用旧的主页时刻倒退秒针。
      _displayAnchor = _displayAnchor.add(
        widget.displayTime.difference(oldWidget.displayTime),
      );
    }
    _handTime.value = MechanicalTick.snap(
      _displayAnchor.add(_lastElapsed - _anchorElapsed),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _handTime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MoonPhase moon = MoonPhase.atUtc(widget.utcTime);
    final DateTime time = widget.displayTime;
    final String day = time.day.toString().padLeft(2, '0');
    final String label =
        '星期${ClockDial.weekdays[time.weekday - 1]}，'
        '${time.month}月$day日，月相${moon.name}（近似）';
    final ClockDialPainter face = ClockDialPainter(
      time: time,
      moon: moon,
      moonScale: widget.moonScale,
      calendarScale: widget.calendarScale,
      romanScale: widget.romanScale,
      showHands: false,
      showMechanism: false,
    );
    return Semantics(
      label: label,
      image: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey<String>('clock-dial-face'),
                painter: face,
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey<String>('clock-dial-hands'),
                painter: ClockHandsPainter(clock: _handTime, renderer: face),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 指针层只监听量化后的时间，每秒最多八次重画；表盘保留独立的绘制缓存。
class ClockHandsPainter extends CustomPainter {
  ClockHandsPainter({required this.clock, required this.renderer})
    : super(repaint: clock);
  final ValueListenable<DateTime> clock;
  final ClockDialPainter renderer;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.paintTourbillon(canvas, size, clock.value);
    renderer.paintHands(canvas, size, clock.value);
  }

  @override
  bool shouldRepaint(covariant ClockHandsPainter oldDelegate) =>
      oldDelegate.clock != clock ||
      renderer.shouldRepaint(oldDelegate.renderer);
}

/// 已确认的机械表盘：XII 下方小月相、三点位星期日历、VI 上方开放式陀飞轮。
/// 珐琅、刻度和日历留在静态画布；指针与机械结构由独立活动画布驱动。
class ClockDialPainter extends CustomPainter {
  const ClockDialPainter({
    required this.time,
    required this.moon,
    this.showHands = true,
    this.showMechanism = true,
    this.showComplications = true,
    this.moonScale = 1,
    this.calendarScale = 1,
    this.romanScale = 1,
  });

  final DateTime time;
  final MoonPhase moon;
  final bool showHands;
  final bool showMechanism;
  final bool showComplications;
  final double moonScale, calendarScale, romanScale;

  static const List<String> _roman = <String>[
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double caseRadius = math.min(size.width, size.height) / 2 - 4;
    if (caseRadius <= 0) return;
    final double radius = caseRadius * .94;
    _case(canvas, center, caseRadius, radius);
    _indices(canvas, center, radius);
    for (int hour = 1; hour <= 12; hour++) {
      final double angle = -math.pi / 2 + hour * math.pi * 2 / 12;
      final Offset position =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * .80);
      _text(
        canvas,
        _roman[hour - 1],
        position,
        fontSize:
            (radius * .17).clamp(6, 17) *
            ClockSettings.componentScale(romanScale),
        color: const Color(0xFF162332),
        fontFamily: 'serif',
        maxWidth: radius * .45 * ClockSettings.componentScale(romanScale),
        raised: true,
      );
    }
    if (showComplications) {
      // 以各组件的几何中心缩放，不移动原来的月相与日历锚点。
      final Offset calendarCenter = center + Offset(radius * .4, 0);
      canvas.save();
      canvas.translate(calendarCenter.dx, calendarCenter.dy);
      canvas.scale(ClockSettings.componentScale(calendarScale));
      canvas.translate(-calendarCenter.dx, -calendarCenter.dy);
      _calendar(canvas, center, radius);
      canvas.restore();
      canvas.save();
      canvas.translate(center.dx, center.dy - radius * .52);
      canvas.scale(.56 * ClockSettings.componentScale(moonScale));
      canvas.translate(-center.dx, -center.dy - radius * .375);
      _moon(canvas, center, radius);
      canvas.restore();
    }
    if (showMechanism) paintTourbillon(canvas, size, time);
    if (showHands) paintHands(canvas, size, MechanicalTick.snap(time));
  }

  /// 多层精钢倒角包围白色釉面，反光方向统一；细微暖灰边缘模拟珐琅弧度。
  void _case(Canvas canvas, Offset center, double outer, double radius) {
    final Rect metal = Rect.fromCircle(center: center, radius: outer);
    canvas.drawCircle(
      center + Offset(0, outer * .025),
      outer,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outer * .025),
    );
    canvas.drawCircle(
      center,
      outer,
      Paint()
        ..shader = const SweepGradient(
          startAngle: -.6,
          endAngle: 2 * math.pi - .6,
          colors: <Color>[
            Color(0xFF9BA5AF),
            Color(0xFFF6F7F7),
            Color(0xFF5C6570),
            Color(0xFFCDD4D8),
            Color(0xFFFFFFFF),
            Color(0xFF646F79),
            Color(0xFFD5DBDE),
            Color(0xFF9BA5AF),
          ],
          stops: <double>[0, .12, .26, .4, .52, .68, .84, 1],
        ).createShader(metal),
    );
    canvas.drawCircle(
      center,
      outer * .982,
      Paint()
        ..color = const Color(0xFFFAFCFC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer * .007,
    );
    canvas.drawCircle(
      center,
      radius + outer * .012,
      Paint()
        ..shader = const SweepGradient(
          colors: <Color>[
            Color(0xFF303B46),
            Color(0xFFDFE2E2),
            Color(0xFF78818A),
            Color(0xFF303B46),
          ],
        ).createShader(metal),
    );
    final Rect enamel = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.4),
          radius: 1.25,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFFFFEFB),
            Color(0xFFF8F5EF),
            Color(0xFFDCD8CE),
          ],
          stops: <double>[0, .63, .86, 1],
        ).createShader(enamel),
    );
    canvas.drawCircle(
      center,
      radius * .994,
      Paint()
        ..color = const Color(0x806D716D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .008,
    );
    // 珐琅保留光滑釉面，只增加宽柔高光，不加入纸张或磨砂式噪点。
    canvas.drawArc(
      Rect.fromCircle(
        center: center + Offset(radius * .025, radius * .025),
        radius: radius * .96,
      ),
      3.65,
      1.35,
      false,
      Paint()
        ..color = const Color(0xB3FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .018
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .012),
    );
  }

  /// 分钟轨道与凸起小刻度分开绘制，保留真实表盘常见的内外轨道和金属亮边。
  void _indices(Canvas canvas, Offset center, double radius) {
    final Paint rail = Paint()
      ..color = const Color(0x9A61666B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (radius * .004).clamp(.3, .55);
    canvas.drawCircle(center, radius * .96, rail);
    canvas.drawCircle(center, radius * .90, rail);
    for (int index = 0; index < 60; index++) {
      final bool hour = index % 5 == 0;
      final double width = radius * (hour ? .022 : .011);
      final Rect tick = Rect.fromLTRB(
        -width / 2,
        -radius * .956,
        width / 2,
        -radius * (hour ? .888 : .916),
      );
      final RRect baton = RRect.fromRectAndRadius(
        tick,
        Radius.circular(radius * .003),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(index * 2 * math.pi / 60);
      canvas.drawRRect(
        baton.shift(Offset(radius * .006, radius * .009)),
        Paint()..color = const Color(0x554B443A),
      );
      canvas.drawRRect(
        baton,
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[
              Color(0xFF384451),
              Color(0xFFB4BDC4),
              Color(0xFF283848),
            ],
            stops: <double>[0, .42, 1],
          ).createShader(tick),
      );
      canvas.drawLine(
        tick.topLeft,
        tick.bottomLeft,
        Paint()
          ..color = const Color(0xFFE4E6E4)
          ..strokeWidth = radius * .004,
      );
      canvas.restore();
    }
  }

  /// 只画活动指针。时、分针同时计入小步进秒数，分钟交界不突然跳位。
  void paintHands(
    Canvas canvas,
    Size size,
    DateTime instant, {
    HandArtwork? layer,
  }) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) / 2 - 4) * .94;
    if (radius <= 0) return;
    final double secondValue =
        instant.second +
        instant.millisecond / 1000 +
        instant.microsecond / 1000000;
    final double hour =
        (instant.hour % 12 + instant.minute / 60 + secondValue / 3600) / 12;
    final double minute = (instant.minute + secondValue / 60) / 60;
    const List<Color> steel = <Color>[
      Color(0xFF07162D),
      Color(0xFF254E7A),
      Color(0xFF8BB4D0),
      Color(0xFF183D68),
      Color(0xFF061327),
    ];
    if (layer == null || layer == HandArtwork.hour) {
      _hand(
        canvas,
        center,
        radius,
        hour,
        length: .70,
        halfWidth: .044,
        colors: steel,
      );
    }
    if (layer == null || layer == HandArtwork.minute) {
      _hand(
        canvas,
        center,
        radius,
        minute,
        length: .94,
        halfWidth: .028,
        colors: steel,
      );
    }
    if (layer == null || layer == HandArtwork.second) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(secondValue / 60 * 2 * math.pi);
      final Paint second = Paint()
        ..color = const Color(0xFF173E68)
        ..strokeWidth = (radius * .014).clamp(.65, 1.2)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(radius * .01, radius * .18),
        Offset(radius * .01, -radius * .955),
        Paint()
          ..color = const Color(0x44362F26)
          ..strokeWidth = radius * .018,
      );
      canvas.drawLine(
        Offset(0, radius * .18),
        Offset(0, -radius * .955),
        second,
      );
      canvas.drawCircle(
        Offset(0, radius * .13),
        radius * .033,
        Paint()..color = const Color(0xFFF8F7F1),
      );
      canvas.drawCircle(
        Offset(0, radius * .13),
        radius * .033,
        second..style = PaintingStyle.stroke,
      );
      canvas.restore();
    }
    if (layer == null || layer == HandArtwork.pin) {
      final Rect pin = Rect.fromCircle(center: center, radius: radius * .058);
      canvas.drawCircle(
        center + Offset(radius * .009, radius * .016),
        radius * .064,
        Paint()
          ..color = const Color(0x5544382C)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .012),
      );
      canvas.drawCircle(
        center,
        radius * .058,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.35, -.4),
            colors: <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFB5C2CD),
              Color(0xFF46596A),
            ],
          ).createShader(pin),
      );
      canvas.drawCircle(
        center,
        radius * .025,
        Paint()..color = const Color(0xFF0B294C),
      );
      canvas.drawCircle(
        center - Offset(radius * .008, radius * .008),
        radius * .008,
        Paint()..color = const Color(0xFFB8D1E0),
      );
    }
  }

  /// 叶形针尖分别接近小时刻度与分钟轨道；窄针尖和明暗切面便于区分落点。
  /// 使用轮廓阴影而非大面积模糊，保持小表盘清晰并减少逐秒重绘成本。
  void _hand(
    Canvas canvas,
    Offset center,
    double radius,
    double value, {
    required double length,
    required double halfWidth,
    required List<Color> colors,
  }) {
    final double tip = radius * length;
    final double width = radius * halfWidth;
    final double tail = radius * .09;
    final Path hand = Path()
      ..moveTo(0, -tip)
      ..quadraticBezierTo(width * .28, -tip * .73, width, -tip * .42)
      ..quadraticBezierTo(width * .58, -tip * .15, width * .35, tail * .45)
      ..lineTo(0, tail)
      ..lineTo(-width * .35, tail * .45)
      ..quadraticBezierTo(-width * .58, -tip * .15, -width, -tip * .42)
      ..quadraticBezierTo(-width * .28, -tip * .73, 0, -tip)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(value * 2 * math.pi);
    canvas.drawPath(
      hand.shift(Offset(radius * .012, radius * .018)),
      Paint()..color = const Color(0x55362D24),
    );
    canvas.drawPath(
      hand,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
          stops: const <double>[0, .40, .48, .52, 1],
        ).createShader(Rect.fromLTRB(-width, -tip, width, tail)),
    );
    canvas.drawPath(
      hand,
      Paint()
        ..color = const Color(0xFF0A1C32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * .006).clamp(.3, .7),
    );
    canvas.restore();
  }

  /// 组合星期与日期窗口位于 III 内侧，留出中央轴和外圈罗马数字的位置。
  void _calendar(Canvas canvas, Offset center, double radius) {
    final Rect rect = Rect.fromLTWH(
      center.dx + radius * .13,
      center.dy - radius * .1175,
      radius * .54,
      radius * .235,
    );
    final RRect window = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius * .035),
    );
    canvas.drawRRect(
      window.shift(Offset(radius * .006, radius * .012)),
      Paint()
        ..color = const Color(0x553B342B)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .009),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFD7D1C5), Color(0xFFFFFEF8)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      window,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF686A69),
            Color(0xFFF4F0E6),
            Color(0xFFACA79B),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .02,
    );
    final double divider = rect.left + rect.width * .61;
    canvas.drawLine(
      Offset(divider, rect.top + rect.height * .15),
      Offset(divider, rect.bottom - rect.height * .15),
      Paint()
        ..color = const Color(0xFFB0AAA0)
        ..strokeWidth = radius * .008,
    );
    _calendarLabel(
      canvas,
      '周${ClockDial.weekdays[time.weekday - 1]}',
      Offset(rect.left + rect.width * .305, rect.center.dy),
      fontSize: radius * .135,
      color: const Color(0xFF2B3035),
      maxWidth: rect.width * .53,
    );
    _calendarLabel(
      canvas,
      time.day.toString().padLeft(2, '0'),
      Offset(divider + rect.width * .195, rect.center.dy),
      fontSize: radius * .135,
      color: const Color(0xFF2B3035),
      maxWidth: rect.width * .32,
    );
  }

  /// 机械月相窗：双月盘每个朔望月转半圈，圆月由两侧弧形遮罩逐渐显露。
  /// 满月居中、新月藏于遮罩后；星星随月盘转动，不叠加独立图标或月相文字。
  void _moon(Canvas canvas, Offset dialCenter, double radius) {
    // 整个窗口略微上移，给 V、VI、VII 留出边框与字形之间的间距。
    final Offset center = dialCenter - Offset(0, radius * .045);
    Offset point(double x, double y) => center + Offset(x * radius, y * radius);
    final Path aperture = Path()
      ..moveTo(point(-.46, .61).dx, point(-.46, .61).dy)
      ..cubicTo(
        point(-.46, .40).dx,
        point(-.46, .40).dy,
        point(-.25, .23).dx,
        point(-.25, .23).dy,
        point(0, .23).dx,
        point(0, .23).dy,
      )
      ..cubicTo(
        point(.25, .23).dx,
        point(.25, .23).dy,
        point(.46, .40).dx,
        point(.46, .40).dy,
        point(.46, .61).dx,
        point(.46, .61).dy,
      )
      ..cubicTo(
        point(.34, .61).dx,
        point(.34, .61).dy,
        point(.34, .47).dx,
        point(.34, .47).dy,
        point(.23, .49).dx,
        point(.23, .49).dy,
      )
      ..cubicTo(
        point(.12, .50).dx,
        point(.12, .50).dy,
        point(.12, .61).dx,
        point(.12, .61).dy,
        point(0, .61).dx,
        point(0, .61).dy,
      )
      ..cubicTo(
        point(-.12, .61).dx,
        point(-.12, .61).dy,
        point(-.12, .50).dx,
        point(-.12, .50).dy,
        point(-.23, .49).dx,
        point(-.23, .49).dy,
      )
      ..cubicTo(
        point(-.34, .47).dx,
        point(-.34, .47).dy,
        point(-.34, .61).dx,
        point(-.34, .61).dy,
        point(-.46, .61).dx,
        point(-.46, .61).dy,
      )
      ..close();
    final Rect bounds = Rect.fromLTRB(
      center.dx - radius * .46,
      center.dy + radius * .23,
      center.dx + radius * .46,
      center.dy + radius * .61,
    );
    canvas.drawPath(
      aperture.shift(Offset(0, radius * .012)),
      Paint()
        ..color = const Color(0x66342C24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .03,
    );
    canvas.save();
    canvas.clipPath(aperture);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A1537), Color(0xFF203D70)],
        ).createShader(bounds),
    );
    final Offset discCenter = point(0, .75);
    canvas.translate(discCenter.dx, discCenter.dy);
    canvas.rotate(math.pi * moon.fraction);
    const List<Offset> stars = <Offset>[
      Offset(-.45, -.24),
      Offset(-.16, -.35),
      Offset(0, -.52),
      Offset(.45, -.24),
      Offset(.56, .13),
      Offset(.10, .47),
      Offset(-.30, .30),
      Offset(.34, .35),
      Offset(-.56, .13),
      Offset(.16, -.35),
    ];
    for (int index = 0; index < stars.length; index++) {
      _star(
        canvas,
        stars[index] * radius,
        radius * (index.isEven ? .027 : .019),
      );
    }
    for (final double direction in const <double>[-1, 1]) {
      final Offset moonCenter = Offset(direction * radius * .34, 0);
      final Rect disc = Rect.fromCircle(
        center: moonCenter,
        radius: radius * .155,
      );
      canvas.drawCircle(
        moonCenter,
        radius * .155,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.35, -.4),
            radius: 1,
            colors: <Color>[
              Color(0xFFFFEAB2),
              Color(0xFFE5C277),
              Color(0xFFB88A40),
            ],
            stops: <double>[0, .65, 1],
          ).createShader(disc),
      );
      canvas.drawCircle(
        moonCenter,
        radius * .155,
        Paint()
          ..color = const Color(0xFFEDD496)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .006,
      );
    }
    canvas.restore();
    canvas.drawPath(
      aperture,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF5F6B76),
            Color(0xFFE5E1D5),
            Color(0xFF8E9396),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius * .012).clamp(.45, 1),
    );
  }

  /// 月盘上的五角星使用矢量绘制，跟随同一转盘变换，无位图资源或网络依赖。
  void _star(Canvas canvas, Offset center, double radius) {
    final Path star = Path();
    for (int vertex = 0; vertex < 10; vertex++) {
      final double angle = -math.pi / 2 + vertex * math.pi / 5;
      final double distance = vertex.isEven ? radius : radius * .42;
      final Offset point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      if (vertex == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFE6C980));
  }

  /// 只在绘制时创建短生命周期文字对象，使用后释放底层 paragraph。
  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    required double maxWidth,
    String? fontFamily,
    bool raised = false,
  }) {
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontFamily: fontFamily,
          fontWeight: raised ? FontWeight.w700 : FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double scale = label.width > 0
        ? math.min(1, maxWidth / label.width)
        : 1;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    if (raised) {
      final TextStyle base = label.text!.style!;
      label.text = TextSpan(
        text: text,
        style: base.copyWith(
          color: const Color(0xFF747D84),
          shadows: <Shadow>[
            Shadow(
              color: const Color(0x70504537),
              offset: Offset(fontSize * .045, fontSize * .08),
              blurRadius: fontSize * .07,
            ),
          ],
        ),
      );
      label.layout();
      label.paint(
        canvas,
        Offset(
          -label.width / 2 + fontSize * .035,
          -label.height / 2 + fontSize * .055,
        ),
      );
      label.text = TextSpan(
        text: text,
        style: base.copyWith(
          foreground: Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF142032),
                Color(0xFF879099),
                Color(0xFF1B2939),
                Color(0xFF0A1422),
              ],
              stops: <double>[0, .22, .48, 1],
            ).createShader(Rect.fromLTWH(0, 0, label.width, label.height)),
        ),
      );
      label.layout();
    }
    label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
    canvas.restore();
    label.dispose();
  }

  /// 日历两栏使用相同字体和字号，去除段落上下额外行距，再按可见文本框居中。
  void _calendarLabel(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    required double maxWidth,
  }) {
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    )..layout();
    final List<TextBox> boxes = label.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final Rect? ink = boxes.isEmpty
        ? null
        : boxes
              .map((TextBox box) => box.toRect())
              .reduce((Rect a, Rect b) => a.expandToInclude(b));
    final double scale = label.width > 0
        ? math.min(1, maxWidth / label.width)
        : 1;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    label.paint(
      canvas,
      Offset(-label.width / 2, -(ink?.center.dy ?? label.height / 2)),
    );
    canvas.restore();
    label.dispose();
  }

  /// 开放式陀飞轮：凹入表盘的金属框、齿轮、摆轮、游丝和三臂笼架。
  /// 陀飞轮单独随活动画布更新；笼架每分钟一圈，游丝按机械摆频小幅往复。
  /// 所有角度取自绝对时间，恢复窗口后不会补播动画或累计走时误差。
  void paintTourbillon(
    Canvas canvas,
    Size size,
    DateTime instant, {
    TourbillonArtwork? layer,
    bool freezeCage = false,
  }) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) / 2 - 4) * .94;
    if (radius > 0) {
      _tourbillon(
        canvas,
        center + Offset(0, radius * .45),
        radius * .245,
        instant,
        layer: layer,
        freezeCage: freezeCage,
      );
    }
  }

  void _tourbillon(
    Canvas canvas,
    Offset center,
    double radius,
    DateTime instant, {
    TourbillonArtwork? layer,
    bool freezeCage = false,
  }) {
    final double seconds =
        instant.second +
        instant.millisecond / 1000 +
        instant.microsecond / 1000000;
    final double cageAngle = freezeCage ? 0.0 : seconds / 60 * math.pi * 2;
    final double balanceSwing = math.cos(seconds * math.pi * 8) * .30;
    final Rect rim = Rect.fromCircle(center: center, radius: radius);
    if (layer != TourbillonArtwork.mechanism) {
      canvas.drawCircle(
        center + Offset(0, radius * .025),
        radius * 1.025,
        Paint()
          ..color = const Color(0x553C3A32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .045),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const SweepGradient(
            colors: <Color>[
              Color(0xFFEAEDEE),
              Color(0xFF657079),
              Color(0xFFF9FAF7),
              Color(0xFF727B82),
              Color(0xFFEAEDEE),
            ],
          ).createShader(rim),
      );
      canvas.drawCircle(
        center,
        radius * .92,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.3, -.5),
            colors: <Color>[
              Color(0xFF4A4941),
              Color(0xFF111716),
              Color(0xFF020605),
            ],
          ).createShader(rim),
      );
    }
    if (layer != TourbillonArtwork.rim) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius * .90)),
      );
      canvas.translate(center.dx, center.dy);
      canvas.rotate(cageAngle);
      canvas.translate(-center.dx, -center.dy);
      // 后层夹板与齿轮先绘制，摆轮与游丝居中，笼架最后覆盖，形成真实的前后层次。
      _gear(
        canvas,
        center + Offset(-radius * .43, -radius * .43),
        radius * .31,
        14,
        .22,
      );
      _gear(
        canvas,
        center + Offset(radius * .47, -radius * .22),
        radius * .28,
        12,
        -.15,
      );
      _gear(
        canvas,
        center + Offset(radius * .42, radius * .47),
        radius * .26,
        13,
        .3,
      );
      final Offset balance = center + Offset(-radius * .05, radius * .07);
      final Rect wheel = Rect.fromCircle(center: balance, radius: radius * .71);
      canvas.drawCircle(
        balance,
        radius * .68,
        Paint()
          ..shader = const SweepGradient(
            colors: <Color>[
              Color(0xFFECD698),
              Color(0xFF8B6228),
              Color(0xFFFFF0B5),
              Color(0xFFB48841),
              Color(0xFFECD698),
            ],
          ).createShader(wheel)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .075,
      );
      canvas.drawCircle(
        balance,
        radius * .60,
        Paint()
          ..color = const Color(0xFF7F592B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .022,
      );
      for (int i = 0; i < 12; i++) {
        final double angle = i * math.pi / 6 + .1 + balanceSwing;
        final Offset screw =
            balance + Offset(math.cos(angle), math.sin(angle)) * radius * .68;
        canvas.drawCircle(
          screw,
          radius * .036,
          Paint()..color = const Color(0xFFD7BA71),
        );
        canvas.drawLine(
          screw - Offset(radius * .023, 0),
          screw + Offset(radius * .023, 0),
          Paint()
            ..color = const Color(0xFF664625)
            ..strokeWidth = radius * .012,
        );
      }
      final Path spring = Path();
      for (int i = 0; i <= 540; i++) {
        final double angle = i / 540 * math.pi * 10 + balanceSwing;
        final double distance = radius * (.05 + i / 540 * .49);
        final Offset point =
            balance + Offset(math.cos(angle), math.sin(angle)) * distance;
        if (i == 0) {
          spring.moveTo(point.dx, point.dy);
        } else {
          spring.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        spring,
        Paint()
          ..color = const Color(0xFFADC2CA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .014,
      );
      for (int arm = 0; arm < 3; arm++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(arm * math.pi * 2 / 3 - .18);
        final Path bridge = Path()
          ..moveTo(-radius * .10, radius * .12)
          ..lineTo(-radius * .075, -radius * .64)
          ..quadraticBezierTo(0, -radius * .83, radius * .10, -radius * .66)
          ..lineTo(radius * .17, radius * .07)
          ..close();
        canvas.drawPath(
          bridge.shift(Offset(radius * .02, radius * .035)),
          Paint()..color = const Color(0xB0000000),
        );
        canvas.drawPath(
          bridge,
          Paint()
            ..shader =
                const LinearGradient(
                  colors: <Color>[
                    Color(0xFF727F89),
                    Color(0xFFF0F2EB),
                    Color(0xFFB3C0C4),
                    Color(0xFF52616B),
                  ],
                  stops: <double>[0, .35, .49, 1],
                ).createShader(
                  Rect.fromLTRB(
                    -radius * .13,
                    -radius * .8,
                    radius * .18,
                    radius * .12,
                  ),
                ),
        );
        final Offset pin = Offset(radius * .015, -radius * .68);
        canvas.drawCircle(
          pin,
          radius * .055,
          Paint()..color = const Color(0xFF192C43),
        );
        canvas.drawLine(
          pin - Offset(radius * .033, 0),
          pin + Offset(radius * .033, 0),
          Paint()
            ..color = const Color(0xFFB2C1CB)
            ..strokeWidth = radius * .015,
        );
        canvas.restore();
      }
      canvas.drawCircle(
        center,
        radius * .125,
        Paint()..color = const Color(0xFFCAD1CC),
      );
      canvas.drawCircle(
        center,
        radius * .073,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.4),
            colors: <Color>[
              Color(0xFFF6A6B3),
              Color(0xFF9D1D3A),
              Color(0xFF4A091B),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * .08)),
      );
      canvas.restore();
    }
    if (layer != TourbillonArtwork.mechanism) {
      canvas.drawCircle(
        center,
        radius * .94,
        Paint()
          ..color = const Color(0xFFCBCDC4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .022,
      );
      canvas.drawArc(
        rim.deflate(radius * .035),
        3.8,
        1.7,
        false,
        Paint()
          ..color = const Color(0xB3FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .018,
      );
    }
  }

  /// 齿顶与齿根交替构成开放式齿轮，保留深色中心孔和三根轮辐。
  void _gear(
    Canvas canvas,
    Offset center,
    double radius,
    int teeth,
    double phase,
  ) {
    final Path teethPath = Path();
    for (int vertex = 0; vertex < teeth * 4; vertex++) {
      final double angle = phase + vertex * math.pi / (teeth * 2);
      final double distance =
          radius * (vertex % 4 == 0 || vertex % 4 == 3 ? .86 : 1);
      final Offset point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      if (vertex == 0) {
        teethPath.moveTo(point.dx, point.dy);
      } else {
        teethPath.lineTo(point.dx, point.dy);
      }
    }
    teethPath.close();
    canvas.drawPath(
      teethPath,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[
            Color(0xFFF4D89D),
            Color(0xFFA0773F),
            Color(0xFFE5BC71),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * .64,
      Paint()..color = const Color(0xFF252B29),
    );
    for (int spoke = 0; spoke < 3; spoke++) {
      final double angle = phase + spoke * math.pi * 2 / 3;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius * .70,
        Paint()
          ..color = const Color(0xFFD6AF69)
          ..strokeWidth = radius * .14,
      );
    }
    canvas.drawCircle(
      center,
      radius * .12,
      Paint()..color = const Color(0xFF7B162C),
    );
  }

  @override
  bool shouldRepaint(covariant ClockDialPainter oldDelegate) =>
      oldDelegate.showHands != showHands ||
      oldDelegate.showMechanism != showMechanism ||
      oldDelegate.showComplications != showComplications ||
      oldDelegate.moonScale != moonScale ||
      oldDelegate.calendarScale != calendarScale ||
      oldDelegate.romanScale != romanScale ||
      oldDelegate.time.year != time.year ||
      oldDelegate.time.month != time.month ||
      oldDelegate.time.day != time.day ||
      oldDelegate.moon.utcMinute != moon.utcMinute ||
      ((showHands || showMechanism) &&
          MechanicalTick.snap(oldDelegate.time) != MechanicalTick.snap(time));
}
