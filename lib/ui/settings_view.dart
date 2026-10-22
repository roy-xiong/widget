import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/clock_settings.dart';
import 'clock_controller.dart';

/// 设置页只管理搜索输入和搜索请求代次，计时、持久化与天气缓存由 Controller 所有。
class SettingsView extends StatefulWidget {
  const SettingsView({required this.controller, super.key});
  final ClockController controller;
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _query = TextEditingController();
  List<WeatherCity> _results = <WeatherCity>[];
  bool _searching = false;
  String? _message;
  int _generation = 0;
  Future<void> _search() async {
    final int generation = ++_generation;
    if (_query.text.trim().length < 2) {
      setState(() => _message = '请输入至少两个字符');
      return;
    }
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final List<WeatherCity> cities = await widget.controller.weather.search(
        _query.text,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = cities;
        _message = cities.isEmpty ? '未找到城市，可尝试拼音或英文名称' : null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _message = '搜索失败，请检查网络后重试');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ClockController vm = widget.controller;
    final ClockSettings settings = vm.settings;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF343B48)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '时钟设置',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '返回时钟',
                  onPressed: () => unawaited(vm.setShowingSettings(false)),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
              children: <Widget>[
                SegmentedButton<ClockStyle>(
                  segments: const <ButtonSegment<ClockStyle>>[
                    ButtonSegment(
                      value: ClockStyle.mechanical,
                      label: Text('机械月相'),
                      icon: Icon(Icons.watch_outlined),
                    ),
                    ButtonSegment(
                      value: ClockStyle.manila,
                      label: Text('马尼拉'),
                      icon: Icon(Icons.flip),
                    ),
                  ],
                  selected: <ClockStyle>{settings.style},
                  onSelectionChanged: (Set<ClockStyle> values) => unawaited(
                    vm.update(settings.copyWith(style: values.first)),
                  ),
                ),
                if (vm.window.supported) ...<Widget>[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('始终置顶'),
                    subtitle: const Text('浮在普通应用窗口上方'),
                    value: settings.alwaysOnTop,
                    onChanged: (bool value) => unawaited(
                      vm.update(settings.copyWith(alwaysOnTop: value)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('屏幕边缘吸附'),
                    subtitle: const Text('拖动松手时靠近边缘自动对齐'),
                    value: settings.snapToEdge,
                    onChanged: (bool value) => unawaited(
                      vm.update(settings.copyWith(snapToEdge: value)),
                    ),
                  ),
                  Text('时钟大小  ${(settings.scale * 100).round()}%'),
                  Slider(
                    value: settings.scale,
                    min: .7,
                    max: 1.6,
                    divisions: 18,
                    label: '${(settings.scale * 100).round()}%',
                    onChanged: (double value) =>
                        unawaited(vm.update(settings.copyWith(scale: value))),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  '天气城市 · ${settings.city.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  children: WeatherCity.presets
                      .map(
                        (WeatherCity city) => ChoiceChip(
                          label: Text(city.name),
                          selected: city.key == settings.city.key,
                          onSelected: (_) => unawaited(
                            vm.update(settings.copyWith(city: city)),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => unawaited(_search()),
                  decoration: InputDecoration(
                    labelText: '搜索其他城市',
                    hintText: '例如 Suzhou、Paris',
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: '搜索城市',
                            onPressed: () => unawaited(_search()),
                            icon: const Icon(Icons.search),
                          ),
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _message!,
                      style: const TextStyle(color: Color(0xFFD6C38F)),
                    ),
                  ),
                ..._results.map(
                  (WeatherCity city) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(city.name),
                    trailing: city.key == settings.city.key
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () =>
                        unawaited(vm.update(vm.settings.copyWith(city: city))),
                  ),
                ),
                if (vm.settingsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      vm.settingsError!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  '时间跟随本机系统时钟与时区。\n天气约每 15 分钟更新，断网时保留上次数据。\n天气数据：Open-Meteo.com（非商业用途）',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF959DAB),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
