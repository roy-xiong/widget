import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/weather_snapshot.dart';
import 'flip_tile.dart';

/// TouchFLO / Sense 早期时钟布局：两块白色翻页牌叠在深色天气底座上。
/// 面板以固定设计坐标绘制后等比缩放，窄窗口和横屏均保持牌面比例。
class ManilaClock extends StatelessWidget {
  const ManilaClock({
    required this.time,
    required this.city,
    required this.weather,
    required this.loading,
    required this.error,
    required this.refresh,
    super.key,
  });
  final DateTime time;
  final String city;
  final WeatherSnapshot? weather;
  final bool loading;
  final String? error;
  final VoidCallback refresh;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 356,
      height: 288,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 76,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF53555A)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFF3F4248),
                    Color(0xFF17191E),
                    Color(0xFF24262C),
                  ],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 13,
            top: 0,
            width: 159,
            height: 160,
            child: FlipTile(
              key: const ValueKey<String>('hours'),
              value: time.hour.toString().padLeft(2, '0'),
            ),
          ),
          Positioned(
            right: 13,
            top: 0,
            width: 159,
            height: 160,
            child: FlipTile(
              key: const ValueKey<String>('minutes'),
              value: time.minute.toString().padLeft(2, '0'),
            ),
          ),
          Positioned(
            top: 166,
            left: 20,
            right: 20,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${time.month}月${time.day}日 周${'一二三四五六日'[time.weekday - 1]}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC6C9D0),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 194,
            left: 18,
            width: 82,
            height: 70,
            child: Semantics(
              label: weather?.description ?? '天气',
              image: true,
              child: CustomPaint(
                painter: WeatherArtwork(
                  code: weather?.code ?? 2,
                  isDay: weather?.isDay ?? true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 198,
            left: 110,
            right: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  weather == null ? '—°' : '${weather!.temperature.round()}°',
                  style: const TextStyle(
                    fontSize: 47,
                    height: 1.1,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Text(
                        weather?.description ?? (loading ? '正在获取天气' : '暂无天气'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        weather == null
                            ? '点击下方刷新'
                            : '高 ${weather!.high?.round() ?? '—'}°  低 ${weather!.low?.round() ?? '—'}°',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB8BCC6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            bottom: 1,
            height: 29,
            child: TextButton(
              onPressed: loading ? null : refresh,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFFA8AEB9),
                disabledForegroundColor: const Color(0xFFA8AEB9),
              ),
              child: Text(
                error ??
                    (loading
                        ? '正在更新…'
                        : weather == null
                        ? '刷新天气'
                        : '${weather!.isStale(time) ? '上次天气 · ' : ''}${weather!.fetchedAt.hour.toString().padLeft(2, '0')}:${weather!.fetchedAt.minute.toString().padLeft(2, '0')} 更新 · Open-Meteo'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
