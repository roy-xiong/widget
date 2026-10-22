import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/weather_snapshot.dart';
import 'flip_tile.dart';

/// 按早期 HTC Sense 参考排布：瘦长翻页牌覆盖玻璃底座，天气图案位于底部中央。
/// 玻璃区域的实际窗口坐标单独报告给 AppKit，使桌面背景也能参与原生模糊。
class ManilaClock extends StatefulWidget {
  const ManilaClock({
    required this.time,
    required this.city,
    required this.weather,
    required this.loading,
    required this.error,
    required this.refresh,
    this.onGlassRect,
    super.key,
  });
  final DateTime time;
  final String city;
  final WeatherSnapshot? weather;
  final bool loading;
  final String? error;
  final VoidCallback refresh;
  final ValueChanged<Rect>? onGlassRect;
  @override
  State<ManilaClock> createState() => _ManilaClockState();
}

class _ManilaClockState extends State<ManilaClock> {
  final GlobalKey _glassKey = GlobalKey();
  Rect? _reportedRect;

  /// FittedBox 会改变缩放，因此分别转换两端坐标，不能直接把未缩放 size 发给原生。
  void _reportGlass() {
    if (!mounted || widget.onGlassRect == null) return;
    final RenderObject? object = _glassKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return;
    final Rect rect = Rect.fromPoints(
      object.localToGlobal(Offset.zero),
      object.localToGlobal(Offset(object.size.width, object.size.height)),
    );
    if (rect == _reportedRect || !rect.isFinite || rect.isEmpty) return;
    _reportedRect = rect;
    widget.onGlassRect?.call(rect);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportGlass());
    final WeatherSnapshot? weather = widget.weather;
    const TextStyle label = TextStyle(
      fontFamily: 'Helvetica Neue',
      fontFamilyFallback: <String>['PingFang SC', 'Heiti SC'],
      decoration: TextDecoration.none,
      fontSize: 12,
      color: Colors.white,
      height: 1.15,
      shadows: <Shadow>[
        Shadow(color: Color(0xB0000000), blurRadius: 2, offset: Offset(0, 1)),
      ],
    );
    final String update = weather == null
        ? '点击刷新天气'
        : '${weather.isStale(widget.time) ? '上次天气 · ' : ''}${weather.fetchedAt.hour.toString().padLeft(2, '0')}:${weather.fetchedAt.minute.toString().padLeft(2, '0')} 更新 · Open-Meteo';
    return AspectRatio(
      aspectRatio: 360 / 250,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 360,
          height: 250,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 16,
                height: 214,
                child: Container(
                  key: _glassKey,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x30000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: const Color(0x60FFFFFF),
                            width: .65,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0x45E8F0F4),
                              Color(0x253C4852),
                              Color(0x65313A43),
                            ],
                            stops: <double>[0, .45, 1],
                          ),
                        ),
                        child: const Stack(
                          children: <Widget>[
                            Positioned(
                              left: 1,
                              right: 1,
                              top: 1,
                              height: 1,
                              child: ColoredBox(color: Color(0x50FFFFFF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 0,
                width: 142,
                height: 164,
                child: FlipTile(
                  key: const ValueKey<String>('hours'),
                  value: widget.time.hour.toString().padLeft(2, '0'),
                ),
              ),
              Positioned(
                right: 20,
                top: 0,
                width: 142,
                height: 164,
                child: FlipTile(
                  key: const ValueKey<String>('minutes'),
                  value: widget.time.minute.toString().padLeft(2, '0'),
                ),
              ),
              Positioned(
                left: 124,
                top: 160,
                width: 112,
                height: 80,
                child: Tooltip(
                  message: widget.error ?? update,
                  child: Semantics(
                    label: weather?.description ?? '暂无天气',
                    image: true,
                    child: GestureDetector(
                      onTap: widget.loading ? null : widget.refresh,
                      child: CustomPaint(
                        painter: WeatherArtwork(
                          code: weather?.code ?? 3,
                          isDay: weather?.isDay ?? true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 180,
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      weather?.description ??
                          (widget.loading ? '正在更新' : '暂无天气'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label,
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 177,
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '周${'一二三四五六日'[widget.time.weekday - 1]}，${widget.time.month}月${widget.time.day}日',
                      maxLines: 1,
                      style: label.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          weather == null
                              ? '—°'
                              : '${weather.temperature.round()}°',
                          style: label.copyWith(
                            fontSize: 31,
                            fontWeight: FontWeight.w300,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              '高 ${weather?.high?.round() ?? '—'}°',
                              style: label.copyWith(fontSize: 10),
                            ),
                            Text(
                              '低 ${weather?.low?.round() ?? '—'}°',
                              style: label.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.error != null || widget.loading)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: widget.loading ? null : widget.refresh,
                    child: Text(
                      widget.error ?? '正在更新天气…',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label.copyWith(fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 自绘天气插图，不依赖 HTC 图片资源或图片网络请求；仅天气数据变化时重绘。
class WeatherArtwork extends CustomPainter {
  const WeatherArtwork({required this.code, required this.isDay});
  final int code;
  final bool isDay;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 85);
    final bool cloudy = code != 0, wet = code >= 51;
    if (code < 3) {
      final Offset sun = Offset(cloudy ? 65 : 50, cloudy ? 27 : 40);
      if (isDay) {
        for (int i = 0; i < 12; i++) {
          final double angle = i * math.pi / 6;
          canvas.drawLine(
            sun + Offset(math.cos(angle), math.sin(angle)) * 25,
            sun + Offset(math.cos(angle), math.sin(angle)) * 31,
            Paint()
              ..color = const Color(0xCCF5B735)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      canvas.drawCircle(
        sun,
        23,
        Paint()
          ..shader = RadialGradient(
            colors: isDay
                ? const <Color>[
                    Color(0xFFFFF1A5),
                    Color(0xFFF4B72F),
                    Color(0xFFE78717),
                  ]
                : const <Color>[Color(0xFFFFFBE0), Color(0xFFC9CFDE)],
            center: const Alignment(-.3, -.4),
          ).createShader(Rect.fromCircle(center: sun, radius: 23)),
      );
    }
    if (cloudy) {
      final Path cloud = Path()
        ..moveTo(15, 64)
        ..cubicTo(-1, 61, 2, 41, 20, 41)
        ..cubicTo(19, 17, 54, 13, 62, 36)
        ..cubicTo(85, 29, 99, 59, 78, 65)
        ..close();
      canvas.drawShadow(cloud, Colors.black, 4, false);
      canvas.drawPath(
        cloud,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.white, Color(0xFFE2E7EE), Color(0xFF9CAABB)],
          ).createShader(const Rect.fromLTWH(0, 20, 100, 50)),
      );
      if (wet) {
        for (int i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(25 + i * 15, 70),
            Offset(21 + i * 15, 79),
            Paint()
              ..color = const Color(0xFF86BDF7)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WeatherArtwork oldDelegate) =>
      code != oldDelegate.code || isDay != oldDelegate.isDay;
}
