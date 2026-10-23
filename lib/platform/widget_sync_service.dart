import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import '../domain/clock_settings.dart';
import '../ui/clock_dial.dart';

/// iOS 小组件底图同步。滑杆连续变化先合并，绘图进行期间仅保留最后一次设置。
/// 设置与可选底图一次提交，原生端写盘成功后才刷新；只缓存 PNG，绝不跳过月相/日历设置。
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
        final Map<String, Object> payload = <String, Object>{
          'settings': jsonEncode(value.toJson()),
          'romanScale': value.romanScale,
        };
        if (value.romanScale != _lastRoman) {
          final DateTime date = DateTime(2026, 1, 1);
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder)..scale(512 / 360);
          ClockDialPainter(
            time: date,
            moon: MoonPhase.atUtc(date.toUtc()),
            showHands: false,
            showComplications: false,
            showMechanism: false,
            romanScale: value.romanScale,
          ).paint(canvas, const Size(360, 360));
          final ui.Picture picture = recorder.endRecording();
          ui.Image? image;
          try {
            image = await picture.toImage(512, 512);
            final ByteData? bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (_disposed) return;
            if (bytes == null) throw StateError('Missing dial PNG');
            payload['png'] = bytes.buffer.asUint8List();
          } finally {
            image?.dispose();
            picture.dispose();
          }
        }
        if (_disposed) return;
        await _channel.invokeMethod<void>('publishSettings', payload);
        _lastRoman = value.romanScale;
        if (!_disposed) onStatus?.call(null);
      }
    } on PlatformException catch (error) {
      if (!_disposed) {
        onStatus?.call(
          error.code == 'APP_GROUP'
              ? '小组件无法共享设置：重签时 App 与小组件必须保留同一个 App Group'
              : '小组件设置写入失败，请重新打开 App 后重试',
        );
      }
    } catch (_) {
      if (!_disposed) onStatus?.call('小组件同步失败，请重新打开 App 后重试');
    } finally {
      _running = false;
      // 绘图/写盘期间新来的设置不能被已经触发过的防抖定时器遗失。
      if (!_disposed && _pending != null) {
        _timer?.cancel();
        _timer = Timer(
          const Duration(milliseconds: 450),
          () => unawaited(_flush()),
        );
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending = null;
    onStatus = null;
  }
}
