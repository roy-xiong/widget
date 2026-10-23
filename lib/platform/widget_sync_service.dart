import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import '../domain/clock_settings.dart';
import '../ui/clock_dial.dart';

/// iOS 小组件底图同步。滑杆连续变化先合并，绘图进行期间仅保留最后一次设置。
/// 图片限定为 512px，复用真实表盘画笔；小组件自身按时间线绘制日历、月相和指针。
class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel(
    'com.xiongjian.widget/widgets',
  );
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Timer? _timer;
  ClockSettings? _pending;
  bool _running = false, _disposed = false;
  double? _lastRoman;
  void Function(String?)? onStatus;

  void schedule(ClockSettings settings) {
    if (!supported || _disposed) return;
    _pending = settings;
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_flush()),
    );
  }

  Future<void> _flush() async {
    if (_disposed || _running) return;
    _running = true;
    try {
      while (!_disposed && _pending != null) {
        final ClockSettings value = _pending!;
        _pending = null;
        if (value.romanScale == _lastRoman) continue;
        final DateTime date = DateTime(2026, 1, 1);
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder)..scale(512 / 360);
        ClockDialPainter(
          time: date,
          moon: MoonPhase.atUtc(date.toUtc()),
          showHands: false,
          showComplications: false,
          romanScale: value.romanScale,
        ).paint(canvas, const Size(360, 360));
        final ui.Picture picture = recorder.endRecording();
        ui.Image? image;
        try {
          image = await picture.toImage(512, 512);
          final ByteData? bytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (_disposed || bytes == null) continue;
          await _channel.invokeMethod<void>('publishDial', <String, Object>{
            'png': bytes.buffer.asUint8List(),
            'romanScale': value.romanScale,
          });
          _lastRoman = value.romanScale;
          if (!_disposed) onStatus?.call(null);
        } finally {
          image?.dispose();
          picture.dispose();
        }
      }
    } catch (_) {
      if (!_disposed) onStatus?.call('小组件同步失败，请重新打开 App；签名需包含 App Group');
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending = null;
    onStatus = null;
  }
}
