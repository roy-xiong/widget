/// 两种外观使用名称持久化，避免枚举顺序变化导致旧设置错读。
enum ClockStyle { mechanical, manila }

/// 已校验的天气城市；缓存用坐标区分，避免相同城市名串用数据。
class WeatherCity {
  const WeatherCity(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;
  static const WeatherCity beijing = WeatherCity('北京', 39.9042, 116.4074);
  static const List<WeatherCity> presets = <WeatherCity>[
    beijing,
    WeatherCity('上海', 31.2304, 121.4737),
    WeatherCity('广州', 23.1291, 113.2644),
    WeatherCity('深圳', 22.5431, 114.0579),
    WeatherCity('杭州', 30.2741, 120.1551),
    WeatherCity('成都', 30.5728, 104.0668),
    WeatherCity('武汉', 30.5928, 114.3055),
    WeatherCity('香港', 22.3193, 114.1694),
    WeatherCity('东京', 35.6762, 139.6503),
    WeatherCity('伦敦', 51.5074, -.1278),
    WeatherCity('纽约', 40.7128, -74.0060),
  ];
  String get key =>
      '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
  Map<String, Object> toJson() => <String, Object>{
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };
  static WeatherCity? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final Object? name = value['name'],
        lat = value['latitude'],
        lon = value['longitude'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }
    return WeatherCity(name, lat.toDouble(), lon.toDouble());
  }
}

/// 不可变偏好快照，比例始终限制在可操作范围；损坏数据回退到默认值。
class ClockSettings {
  const ClockSettings({
    this.style = ClockStyle.mechanical,
    this.alwaysOnTop = true,
    this.snapToEdge = true,
    this.scale = 1,
    this.city = WeatherCity.beijing,
  });
  final ClockStyle style;
  final bool alwaysOnTop, snapToEdge;
  final double scale;
  final WeatherCity city;
  ClockSettings copyWith({
    ClockStyle? style,
    bool? alwaysOnTop,
    bool? snapToEdge,
    double? scale,
    WeatherCity? city,
  }) => ClockSettings(
    style: style ?? this.style,
    alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    snapToEdge: snapToEdge ?? this.snapToEdge,
    scale: (scale ?? this.scale).clamp(.2, 1.6),
    city: city ?? this.city,
  );
  Map<String, Object> toJson() => <String, Object>{
    'style': style.name,
    'alwaysOnTop': alwaysOnTop,
    'snapToEdge': snapToEdge,
    'scale': scale,
    'city': city.toJson(),
  };
  factory ClockSettings.fromJson(Map<String, dynamic> value) {
    final Object? scale = value['scale'];
    return ClockSettings(
      style: value['style'] == 'manila'
          ? ClockStyle.manila
          : ClockStyle.mechanical,
      alwaysOnTop: value['alwaysOnTop'] is bool
          ? value['alwaysOnTop'] as bool
          : true,
      snapToEdge: value['snapToEdge'] is bool
          ? value['snapToEdge'] as bool
          : true,
      scale: scale is num && scale.isFinite
          ? scale.toDouble().clamp(.2, 1.6)
          : 1,
      city: WeatherCity.fromJson(value['city']) ?? WeatherCity.beijing,
    );
  }
}
