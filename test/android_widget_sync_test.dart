import 'dart:async';
import 'dart:convert';
import 'package:desktop_clock/domain/clock_settings.dart';
import 'package:desktop_clock/platform/widget_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android 三个独立尺寸通过真实同步通道提交，不能被底图缓存跳过', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.xiongjian.widget/widgets');
    final service = WidgetSyncService();
    final received = <Map<String, dynamic>>[];
    Completer<void>? completion;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'publishSettings') {
            final args = call.arguments as Map<Object?, Object?>;
            received.add(
              jsonDecode(args['settings'] as String) as Map<String, dynamic>,
            );
            completion?.complete();
          }
          return null;
        });
    try {
      expect(service.supported, isTrue, reason: 'Android 桌面小组件必须开放设置同步');
      for (final settings in [
        const ClockSettings(),
        const ClockSettings(moonScale: .5),
        const ClockSettings(moonScale: .5, calendarScale: 1.5),
        const ClockSettings(
          moonScale: .5,
          calendarScale: 1.5,
          romanScale: 1.25,
        ),
      ]) {
        await tester.runAsync(() async {
          completion = Completer<void>();
          service.schedule(settings);
          await completion!.future.timeout(const Duration(seconds: 8));
        });
        expect(received.last['moonScale'], settings.moonScale);
        expect(received.last['calendarScale'], settings.calendarScale);
        expect(received.last['romanScale'], settings.romanScale);
      }
    } finally {
      service.dispose();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
