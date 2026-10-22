import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/clock_settings.dart';

/// AppKit 窗口能力的边界；iOS 不调用悬浮接口，测试可整体替换。
class WindowService {
  final MethodChannel _channel = const MethodChannel(
    'com.xiongjian.widget/window',
  );
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  void Function(String)? onAction;
  void attach() {
    if (supported) {
      _channel.setMethodCallHandler((MethodCall call) async {
        onAction?.call(call.method);
      });
    }
  }

  Future<void> configure(ClockSettings settings) async {
    if (supported) {
      await _channel.invokeMethod<void>('configure', settings.toJson());
    }
  }

  Future<void> settingsVisible(bool visible) async {
    if (supported) {
      await _channel.invokeMethod<void>('settingsVisible', visible);
    }
  }

  /// 原生使用屏幕绝对鼠标位置，避免窗口移动后局部坐标变化引起抖动。
  Future<void> drag(String phase) async {
    if (supported) await _channel.invokeMethod<void>('drag', phase);
  }

  /// 仅在玻璃区域改变时由视图报告；原生根据窗口尺寸将坐标转换到 AppKit。
  Future<void> updateGlass(Rect rect) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('glassRect', <String, double>{
        'left': rect.left,
        'top': rect.top,
        'width': rect.width,
        'height': rect.height,
      });
    } on PlatformException {
      /* 窗口关闭期间忽略已失效的装饰层更新。 */
    }
  }

  Future<void> quit() async {
    if (supported) await _channel.invokeMethod<void>('quit');
  }

  void dispose() {
    if (supported) _channel.setMethodCallHandler(null);
    onAction = null;
  }
}
