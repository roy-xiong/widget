import 'package:flutter/material.dart';
import 'data/preferences_repository.dart';
import 'data/weather_repository.dart';
import 'platform/window_service.dart';
import 'ui/clock_app.dart';
import 'ui/clock_controller.dart';

/// Flutter 共用表盘，AppKit 负责 macOS 窗口行为。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ClockApp(
      controller: ClockController(
        preferences: NativePreferencesRepository(),
        weather: OpenMeteoRepository(),
        window: WindowService(),
      ),
    ),
  );
}
