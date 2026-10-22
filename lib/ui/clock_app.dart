import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/clock_settings.dart';
import 'clock_controller.dart';
import 'clock_dial.dart';
import 'manila_clock.dart';
import 'settings_view.dart';

/// 根组件拥有 Controller 生命周期，页面关闭时同时释放计时器、网络和原生回调。
class ClockApp extends StatefulWidget {
  const ClockApp({required this.controller, super.key});
  final ClockController controller;
  @override
  State<ClockApp> createState() => _ClockAppState();
}

class _ClockAppState extends State<ClockApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '桌面时钟',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFCEB77D),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF13161C),
    ),
    home: _ClockHome(controller: widget.controller),
  );
}

/// macOS 保留透明背景；iOS 提供普通时钟页面。布局依赖窗口可用空间，不锁定方向。
class _ClockHome extends StatefulWidget {
  const _ClockHome({required this.controller});
  final ClockController controller;
  @override
  State<_ClockHome> createState() => _ClockHomeState();
}

class _ClockHomeState extends State<_ClockHome> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (BuildContext context, Widget? child) {
      final ClockController vm = widget.controller;
      final bool desktop = vm.window.supported;
      final bool compact = desktop && MediaQuery.sizeOf(context).width < 240;
      final double scale = desktop ? vm.settings.scale : 1;
      final Widget clock = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: desktop
            ? () => unawaited(vm.setShowingSettings(true))
            : null,
        onPanStart: desktop ? (_) => unawaited(vm.drag('begin')) : null,
        onPanUpdate: desktop ? (_) => unawaited(vm.drag('update')) : null,
        onPanEnd: desktop ? (_) => unawaited(vm.drag('end')) : null,
        onPanCancel: desktop ? () => unawaited(vm.drag('end')) : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12 * scale,
            desktop ? 35 * scale : 60,
            12 * scale,
            desktop ? 20 * scale : 40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
              child: ValueListenableBuilder<DateTime>(
                valueListenable: vm.time,
                builder:
                    (BuildContext context, DateTime instant, Widget? child) =>
                        TickerMode(
                          enabled: vm.active,
                          child: vm.settings.style == ClockStyle.mechanical
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: FittedBox(
                                    child: SizedBox(
                                      width: 360,
                                      height: 360,
                                      child: ClockDial(
                                        displayTime: instant,
                                        utcTime: instant.toUtc(),
                                      ),
                                    ),
                                  ),
                                )
                              : ManilaClock(
                                  time: instant,
                                  city: vm.settings.city.name,
                                  weather: vm.snapshot,
                                  loading: vm.loadingWeather,
                                  error: vm.weatherError,
                                  onGlassRect: (Rect rect) =>
                                      unawaited(vm.window.updateGlass(rect)),
                                  refresh: () => unawaited(vm.refreshWeather()),
                                ),
                        ),
              ),
            ),
          ),
        ),
      );
      final Widget toolbar = compact
          ? _button(
              '设置',
              Icons.tune_rounded,
              () => unawaited(vm.setShowingSettings(true)),
              compact: true,
            )
          : Row(
              children: <Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vm.settings.style == ClockStyle.mechanical
                        ? '机械月相'
                        : 'Manila 天气',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDDD7C5),
                    ),
                  ),
                ),
                _button(
                  '切换表盘',
                  Icons.swap_horiz_rounded,
                  () => unawaited(
                    vm.update(
                      vm.settings.copyWith(
                        style: vm.settings.style == ClockStyle.mechanical
                            ? ClockStyle.manila
                            : ClockStyle.mechanical,
                      ),
                    ),
                  ),
                ),
                if (desktop)
                  _button(
                    vm.settings.alwaysOnTop ? '取消置顶' : '始终置顶',
                    vm.settings.alwaysOnTop
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    () => unawaited(
                      vm.update(
                        vm.settings.copyWith(
                          alwaysOnTop: !vm.settings.alwaysOnTop,
                        ),
                      ),
                    ),
                  ),
                _button(
                  '设置',
                  Icons.tune_rounded,
                  () => unawaited(vm.setShowingSettings(true)),
                ),
                if (desktop)
                  _button(
                    '退出时钟',
                    Icons.close_rounded,
                    () => unawaited(vm.window.quit()),
                  ),
              ],
            );
      final Widget content = vm.showingSettings
          ? SettingsView(controller: vm)
          : MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: clock),
                  Positioned(
                    top: desktop ? 1 : 12,
                    left: compact ? null : 8,
                    right: compact ? 1 : 8,
                    child: IgnorePointer(
                      ignoring: desktop && !_hovered,
                      child: AnimatedOpacity(
                        opacity: !desktop || _hovered ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xD9171B22),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: toolbar,
                        ),
                      ),
                    ),
                  ),
                  if (!desktop)
                    const Positioned(
                      bottom: 10,
                      left: 12,
                      right: 12,
                      child: Text(
                        '轻点右上角切换表盘或选择天气城市',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8C929D),
                        ),
                      ),
                    ),
                ],
              ),
            );
      return Scaffold(
        backgroundColor: desktop ? Colors.transparent : const Color(0xFF10141C),
        body: SafeArea(top: !desktop, bottom: !desktop, child: content),
      );
    },
  );

  /// 小窗口保留固定可点击的设置入口；双击表盘和菜单栏入口也可恢复正常大小。
  Widget _button(
    String label,
    IconData icon,
    VoidCallback action, {
    bool compact = false,
  }) => IconButton(
    tooltip: label,
    onPressed: action,
    visualDensity: VisualDensity.compact,
    constraints: BoxConstraints(
      minWidth: compact ? 28 : 34,
      minHeight: compact ? 28 : 34,
    ),
    padding: EdgeInsets.all(compact ? 4 : 6),
    icon: Icon(icon, size: compact ? 14 : 16, color: const Color(0xFFD6D7DC)),
  );
}
