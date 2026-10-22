import 'dart:convert';
import 'package:flutter/services.dart';

/// 原生 UserDefaults 的窄接口，测试可注入内存实现。
abstract class PreferencesRepository {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, Object?> value);
}

/// 原生通道只接受设置与天气两个键，写入由 Controller 串行化。
class NativePreferencesRepository implements PreferencesRepository {
  static const MethodChannel _channel = MethodChannel(
    'com.xiongjian.widget/preferences',
  );
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final String? raw = await _channel.invokeMethod<String>('read', key);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) =>
      _channel.invokeMethod<void>('write', <String, Object>{
        'key': key,
        'value': jsonEncode(value),
      });
}
