import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/preferences_repository.dart';
import '../data/weather_repository.dart';
import '../domain/clock_settings.dart';
import '../domain/weather_snapshot.dart';
import '../platform/window_service.dart';

/// 时钟、偏好、天气的唯一所有者。版本号阻止旧城市响应覆盖新选择，销毁后不通知。
/// 时间使用独立 ValueNotifier，秒级变化不重建设置页和天气网络逻辑。
class ClockController extends ChangeNotifier {
  ClockController({
    required this.preferences,
    required this.weather,
    required this.window,
    this.startTimers = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final PreferencesRepository preferences;
  final WeatherRepository weather;
  final WindowService window;
  final bool startTimers;
  final DateTime Function() _now;
  final ValueNotifier<DateTime> time = ValueNotifier<DateTime>(DateTime.now());
  ClockSettings settings = const ClockSettings();
  WeatherSnapshot? snapshot;
  String? weatherError, settingsError;
  bool loadingWeather = false,
      ready = false,
      showingSettings = false,
      active = true;
  bool _disposed = false;
  int _weatherGeneration = 0;
  String? _requestedCity;
  Timer? _clockTimer, _weatherTimer;
  AppLifecycleListener? _lifecycle;
  Future<void> _writes = Future<void>.value();

  Future<void> initialize() async {
    if (ready || _disposed) return;
    window.attach();
    window.onAction = (String action) {
      if (_disposed) return;
      if (action == 'showSettings') unawaited(setShowingSettings(true));
      if (action == 'togglePin') {
        unawaited(
          update(settings.copyWith(alwaysOnTop: !settings.alwaysOnTop)),
        );
      }
    };
    try {
      final Map<String, dynamic>? saved = await preferences.read('settings');
      if (_disposed) return;
      if (saved != null) settings = ClockSettings.fromJson(saved);
      final Map<String, dynamic>? cache = await preferences.read('weather');
      if (_disposed) return;
      final WeatherSnapshot? previous = cache == null
          ? null
          : WeatherSnapshot.fromJson(cache);
      if (previous?.cityKey == settings.city.key) snapshot = previous;
    } catch (_) {
      settingsError = '设置读取失败，已使用默认值';
    }
    if (_disposed) return;
    ready = true;
    time.value = _now();
    await _configureWindow();
    if (_disposed) return;
    if (startTimers) {
      _lifecycle = AppLifecycleListener(
        onStateChange: (AppLifecycleState state) {
          final bool visible =
              state != AppLifecycleState.hidden &&
              state != AppLifecycleState.paused &&
              state != AppLifecycleState.detached;
          if (active == visible || _disposed) return;
          active = visible;
          if (visible) {
            time.value = _now();
            _startClock();
            if (snapshot == null || snapshot!.isStale(_now())) {
              unawaited(refreshWeather());
            }
          } else {
            _clockTimer?.cancel();
          }
          _notify();
        },
      );
      _startClock();
      _weatherTimer = Timer.periodic(const Duration(minutes: 15), (_) {
        if (active) unawaited(refreshWeather());
      });
      unawaited(refreshWeather());
    }
    _notify();
  }

  /// 每次读取系统绝对时间，跨秒、休眠、手动改时不累计误差。
  void _startClock() {
    _clockTimer?.cancel();
    void tick() {
      if (_disposed || !active) return;
      final DateTime instant = _now();
      time.value = instant;
      _clockTimer = Timer(
        Duration(
          microseconds:
              Duration.microsecondsPerSecond -
              instant.microsecondsSinceEpoch % Duration.microsecondsPerSecond,
        ),
        tick,
      );
    }

    tick();
  }

  Future<void> update(ClockSettings value) async {
    if (_disposed) return;
    final bool cityChanged = settings.city.key != value.city.key;
    settings = value;
    if (cityChanged) {
      ++_weatherGeneration;
      loadingWeather = false;
      _requestedCity = null;
      snapshot = null;
      weatherError = null;
    }
    _notify();
    // 第一次 await 前排队，快速连续调节也按用户操作顺序落盘。
    final Future<void> write = _save('settings', value.toJson());
    await _configureWindow();
    await write;
    if (cityChanged && !_disposed) unawaited(refreshWeather());
  }

  Future<void> _configureWindow() async {
    try {
      await window.configure(settings);
    } catch (_) {
      if (!_disposed) {
        settingsError = '窗口设置未能应用，请重试';
        _notify();
      }
    }
  }

  Future<void> setShowingSettings(bool visible) async {
    if (_disposed) return;
    showingSettings = visible;
    _notify();
    try {
      await window.settingsVisible(visible);
    } catch (_) {
      if (!_disposed) {
        settingsError = '设置窗口调整失败';
        _notify();
      }
    }
  }

  Future<void> refreshWeather() async {
    if (_disposed || (loadingWeather && _requestedCity == settings.city.key)) {
      return;
    }
    final int generation = ++_weatherGeneration;
    final WeatherCity city = settings.city;
    _requestedCity = city.key;
    loadingWeather = true;
    weatherError = null;
    _notify();
    try {
      final WeatherSnapshot result = await weather.fetch(city);
      if (_disposed ||
          generation != _weatherGeneration ||
          result.cityKey != settings.city.key) {
        return;
      }
      snapshot = result;
      await _save('weather', result.toJson());
    } catch (_) {
      if (!_disposed && generation == _weatherGeneration) {
        weatherError = snapshot == null ? '天气获取失败，点击重试' : '更新失败 · 显示上次天气';
      }
    } finally {
      if (!_disposed && generation == _weatherGeneration) {
        loadingWeather = false;
        _notify();
      }
    }
  }

  Future<void> _save(String key, Map<String, Object?> value) {
    _writes = _writes.then((_) => preferences.write(key, value)).catchError((
      Object _,
    ) {
      if (!_disposed) {
        settingsError = '设置保存失败，重启后可能恢复为旧值';
        _notify();
      }
    });
    return _writes;
  }

  Future<void> drag(String phase) async {
    try {
      await window.drag(phase);
    } catch (_) {
      /* 关闭期间丢弃手势。 */
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_weatherGeneration;
    _clockTimer?.cancel();
    _weatherTimer?.cancel();
    _lifecycle?.dispose();
    window.dispose();
    weather.dispose();
    time.dispose();
    super.dispose();
  }
}
