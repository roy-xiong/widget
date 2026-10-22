import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/clock_settings.dart';
import '../domain/weather_snapshot.dart';

/// HTTP 与 JSON 细节不进入 UI，便于验证超时、离线和城市切换竞态。
abstract class WeatherRepository {
  Future<WeatherSnapshot> fetch(WeatherCity city);
  Future<List<WeatherCity>> search(String query);
  void dispose();
}

/// Open-Meteo 非商业免密钥接口，仅发送选中城市的坐标。
/// 每个请求独立关闭连接，限制超时和响应长度，销毁时中断所有在途请求。
class OpenMeteoRepository implements WeatherRepository {
  final Set<HttpClient> _clients = <HttpClient>{};
  bool _disposed = false;
  Future<Map<String, dynamic>> _get(Uri uri) async {
    if (_disposed) throw const HttpException('天气服务已关闭');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    _clients.add(client);
    try {
      return await (() async {
        final HttpClientRequest request = await client.getUrl(uri);
        final HttpClientResponse response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('天气服务暂不可用（${response.statusCode}）');
        }
        final List<int> bytes = <int>[];
        await for (final List<int> part in response) {
          if (bytes.length + part.length > 512 * 1024) {
            throw const FormatException('响应过大');
          }
          bytes.addAll(part);
        }
        final Object? decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('无效天气数据');
        }
        return decoded;
      })().timeout(const Duration(seconds: 15));
    } finally {
      _clients.remove(client);
      client.close(force: true);
    }
  }

  @override
  Future<WeatherSnapshot> fetch(WeatherCity city) async {
    final Map<String, dynamic> data = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
        'latitude': '${city.latitude}',
        'longitude': '${city.longitude}',
        'current': 'temperature_2m,weather_code,is_day',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'forecast_days': '1',
        'timezone': 'auto',
      }),
    );
    final Object? current = data['current'], daily = data['daily'];
    if (current is! Map<String, dynamic>) throw const FormatException('暂无当前天气');
    final Object? temperature = current['temperature_2m'],
        code = current['weather_code'];
    if (temperature is! num ||
        !temperature.isFinite ||
        code is! num ||
        !code.isFinite) {
      throw const FormatException('暂无有效天气');
    }
    double? first(String key) {
      final Object? values = daily is Map<String, dynamic> ? daily[key] : null;
      if (values is! List || values.isEmpty) return null;
      final Object? value = values.first;
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    return WeatherSnapshot(
      cityKey: city.key,
      temperature: temperature.toDouble(),
      code: code.toInt(),
      isDay: current['is_day'] != 0,
      fetchedAt: DateTime.now(),
      high: first('temperature_2m_max'),
      low: first('temperature_2m_min'),
    );
  }

  @override
  Future<List<WeatherCity>> search(String query) async {
    final String name = query.trim();
    if (name.length < 2 || name.length > 80) return <WeatherCity>[];
    final Map<String, dynamic> data = await _get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', <String, String>{
        'name': name,
        'count': '8',
        'language': 'zh',
        'format': 'json',
      }),
    );
    final Object? results = data['results'];
    if (results is! List) return <WeatherCity>[];
    return results
        .map((Object? value) {
          if (value is! Map<String, dynamic>) return null;
          final String region = value['admin1'] is String
              ? value['admin1'] as String
              : '';
          final String name = value['name'] is String
              ? value['name'] as String
              : '';
          return WeatherCity.fromJson(<String, dynamic>{
            ...value,
            'name': region.isEmpty || region == name ? name : '$name · $region',
          });
        })
        .whereType<WeatherCity>()
        .toList(growable: false);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final HttpClient client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
  }
}
