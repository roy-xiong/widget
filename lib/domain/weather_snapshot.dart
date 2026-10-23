/// 天气连同城市和获取时间缓存，离线时明确标记旧数据。
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.cityKey,
    required this.temperature,
    required this.code,
    required this.isDay,
    required this.fetchedAt,
    this.high,
    this.low,
  });
  final String cityKey;
  final double temperature;
  final int code;
  final bool isDay;
  final DateTime fetchedAt;
  final double? high, low;
  bool isStale(DateTime now) =>
      now.difference(fetchedAt) > const Duration(minutes: 45);
  String get description => switch (code) {
    0 => isDay ? '晴' : '晴朗夜空',
    1 || 2 => '晴间多云',
    3 => '阴',
    45 || 48 => '雾',
    >= 51 && <= 57 => '毛毛雨',
    >= 61 && <= 67 => '雨',
    >= 71 && <= 77 => '雪',
    >= 80 && <= 82 => '阵雨',
    85 || 86 => '阵雪',
    >= 95 => '雷雨',
    _ => '天气',
  };
  Map<String, Object?> toJson() => <String, Object?>{
    'cityKey': cityKey,
    'temperature': temperature,
    'code': code,
    'isDay': isDay,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'high': high,
    'low': low,
  };
  static WeatherSnapshot? fromJson(Map<String, dynamic> value) {
    final Object? key = value['cityKey'],
        temperature = value['temperature'],
        code = value['code'],
        rawDate = value['fetchedAt'];
    final DateTime? date = rawDate is String
        ? DateTime.tryParse(rawDate)
        : null;
    if (key is! String ||
        temperature is! num ||
        !temperature.isFinite ||
        code is! num ||
        !code.isFinite ||
        date == null) {
      return null;
    }
    double? number(Object? raw) =>
        raw is num && raw.isFinite ? raw.toDouble() : null;
    return WeatherSnapshot(
      cityKey: key,
      temperature: temperature.toDouble(),
      code: code.toInt(),
      isDay: value['isDay'] != false,
      fetchedAt: date,
      high: number(value['high']),
      low: number(value['low']),
    );
  }
}
