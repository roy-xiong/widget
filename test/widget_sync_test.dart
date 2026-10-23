import 'dart:convert';
import 'package:desktop_clock/domain/clock_settings.dart';
import 'package:desktop_clock/platform/widget_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 经过正式防抖和 MethodChannel，确保只改月相/日历时也会提交设置，不能被底图缓存跳过。
void main() {
  const MethodChannel channel = MethodChannel('com.xiongjian.widget/widgets');
  testWidgets('三个独立尺寸都提交给小组件，不依赖罗马数字底图是否变化', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final List<Map<String, dynamic>> published = <Map<String, dynamic>>[];
    Completer<void>? nextPublish;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'publishSettings') {
            final Map<Object?, Object?> arguments =
                call.arguments as Map<Object?, Object?>;
            published.add(
              jsonDecode(arguments['settings']! as String)
                  as Map<String, dynamic>,
            );
          }
          if (nextPublish?.isCompleted == false) nextPublish?.complete();
          return null;
        });
    final WidgetSyncService service = WidgetSyncService();
    addTearDown(() {
      service.dispose();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    for (final ClockSettings settings in <ClockSettings>[
      const ClockSettings(),
      const ClockSettings(moonScale: .5),
      const ClockSettings(moonScale: .5, calendarScale: 1.5),
      const ClockSettings(moonScale: .5, calendarScale: 1.5, romanScale: 1.25),
    ]) {
      nextPublish = Completer<void>();
      await tester.runAsync(() async {
        // 定时器和 raster.toImage 都在真实异步区运行，不能用真实等待代替推进 FakeAsync。
        service.schedule(settings);
        await nextPublish!.future.timeout(const Duration(seconds: 8));
      });
      expect(published, isNotEmpty, reason: '设置必须独立于 PNG 底图缓存提交');
      expect(published.last['moonScale'], settings.moonScale);
      expect(published.last['calendarScale'], settings.calendarScale);
      expect(published.last['romanScale'], settings.romanScale);
    }
    expect(published.length, 4);
  });
}
import 'dart:async';
