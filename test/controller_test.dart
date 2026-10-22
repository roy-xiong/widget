import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:desktop_clock/data/preferences_repository.dart';
import 'package:desktop_clock/data/weather_repository.dart';
import 'package:desktop_clock/domain/clock_settings.dart';
import 'package:desktop_clock/domain/weather_snapshot.dart';
import 'package:desktop_clock/platform/window_service.dart';
import 'package:desktop_clock/ui/clock_controller.dart';

class MemoryPreferences extends PreferencesRepository {
  final Map<String, Map<String, dynamic>> values =
      <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    values[key] = Map<String, dynamic>.from(value);
  }
}

class PendingWeather extends WeatherRepository {
  final List<(WeatherCity, Completer<WeatherSnapshot>)> requests =
      <(WeatherCity, Completer<WeatherSnapshot>)>[];
  @override
  Future<WeatherSnapshot> fetch(WeatherCity city) {
    final Completer<WeatherSnapshot> result = Completer<WeatherSnapshot>();
    requests.add((city, result));
    return result.future;
  }

  void complete(int index, double temperature) {
    final (WeatherCity city, Completer<WeatherSnapshot> result) =
        requests[index];
    result.complete(
      WeatherSnapshot(
        cityKey: city.key,
        temperature: temperature,
        code: 0,
        isDay: true,
        fetchedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<WeatherCity>> search(String query) async => <WeatherCity>[];
  @override
  void dispose() {}
}

class FakeWindow extends WindowService {
  @override
  bool get supported => false;
}

/// 桌面布局测试使用无平台通道的窗口替身，真实 AppKit 行为由云端及运行检查覆盖。
class FakeDesktopWindow extends FakeWindow {
  @override
  bool get supported => true;
  @override
  void attach() {}
  @override
  Future<void> configure(ClockSettings settings) async {}
  @override
  Future<void> settingsVisible(bool visible) async {}
  @override
  Future<void> updateGlass(Rect rect) async {}
  @override
  void dispose() {}
}

Future<void> settleAsync() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('损坏偏好不能产生无效坐标或异常窗口比例', () {
    final ClockSettings settings = ClockSettings.fromJson(<String, dynamic>{
      'scale': double.nan,
      'city': <String, dynamic>{'name': '异常', 'latitude': 999, 'longitude': 0},
    });
    expect(settings.scale, 1);
    expect(settings.city.key, WeatherCity.beijing.key);
    expect(const ClockSettings().copyWith(scale: 100).scale, 1.6);
    expect(const ClockSettings().copyWith(scale: .01).scale, .2);
    expect(ClockSettings.fromJson(<String, dynamic>{'scale': .1}).scale, .2);
  });
  test('城市切换后较晚完成的旧响应不能覆盖新城市', () async {
    final PendingWeather weather = PendingWeather();
    final ClockController vm = ClockController(
      preferences: MemoryPreferences(),
      weather: weather,
      window: FakeWindow(),
      startTimers: false,
    );
    await vm.initialize();
    final Future<void> first = vm.refreshWeather();
    await vm.update(vm.settings.copyWith(city: WeatherCity.presets[1]));
    await settleAsync();
    expect(weather.requests.length, 2);
    weather.complete(1, 20);
    await settleAsync();
    weather.complete(0, 5);
    await first;
    expect(vm.snapshot?.cityKey, WeatherCity.presets[1].key);
    expect(vm.snapshot?.temperature, 20);
    expect(vm.loadingWeather, false);
    vm.dispose();
  });
  test('北京上海北京快速切换仍可发起最新请求', () async {
    final PendingWeather weather = PendingWeather();
    final ClockController vm = ClockController(
      preferences: MemoryPreferences(),
      weather: weather,
      window: FakeWindow(),
      startTimers: false,
    );
    await vm.initialize();
    final Future<void> first = vm.refreshWeather();
    await vm.update(vm.settings.copyWith(city: WeatherCity.presets[1]));
    await vm.update(vm.settings.copyWith(city: WeatherCity.beijing));
    expect(weather.requests.length, 3);
    weather.complete(0, 1);
    weather.complete(1, 2);
    weather.complete(2, 3);
    await first;
    await settleAsync();
    expect(vm.snapshot?.temperature, 3);
    expect(vm.loadingWeather, false);
    vm.dispose();
  });
  test('销毁后的响应不会触发通知或访问已销毁时钟', () async {
    final PendingWeather weather = PendingWeather();
    final ClockController vm = ClockController(
      preferences: MemoryPreferences(),
      weather: weather,
      window: FakeWindow(),
      startTimers: false,
    );
    await vm.initialize();
    final Future<void> pending = vm.refreshWeather();
    vm.dispose();
    weather.complete(0, 10);
    await pending;
  });
  test('连续调节设置后落盘保留最后一次用户操作', () async {
    final MemoryPreferences preferences = MemoryPreferences();
    final ClockController vm = ClockController(
      preferences: preferences,
      weather: PendingWeather(),
      window: FakeWindow(),
      startTimers: false,
    );
    await vm.initialize();
    await Future.wait(<Future<void>>[
      vm.update(vm.settings.copyWith(scale: .8)),
      vm.update(vm.settings.copyWith(scale: 1.4)),
    ]);
    expect(preferences.values['settings']?['scale'], 1.4);
    vm.dispose();
  });
}
