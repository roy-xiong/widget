import Foundation

/** 与 Flutter 的设置 JSON 共用字段和边界，旧版缺失字段按 100% 处理。 */
struct SharedClockSettings: Equatable, Sendable {
  var moonScale: Double = 1
  var calendarScale: Double = 1
  var romanScale: Double = 1
  var cityName: String = "北京"
  var latitude: Double = 39.9042
  var longitude: Double = 116.4074
  var cityKey: String {
    String(format: "%.4f,%.4f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
  }

  init(raw: String? = nil) {
    guard let raw = raw, let data = raw.data(using: .utf8), data.count <= 131072,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    func component(_ key: String) -> Double {
      guard let value = json[key] as? NSNumber, value.doubleValue.isFinite else { return 1 }
      return min(1.5, max(0.5, value.doubleValue))
    }
    moonScale = component("moonScale")
    calendarScale = component("calendarScale")
    romanScale = component("romanScale")
    if let city = json["city"] as? [String: Any], let name = city["name"] as? String,
       !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 100,
       let lat = city["latitude"] as? NSNumber, let lon = city["longitude"] as? NSNumber,
       lat.doubleValue.isFinite, lon.doubleValue.isFinite,
       (-90...90).contains(lat.doubleValue), (-180...180).contains(lon.doubleValue) {
      cityName = name; latitude = lat.doubleValue; longitude = lon.doubleValue
    }
  }
}

/** 天气保留真实获取时间，扩展离线或 App 被结束后也能标明缓存时效。 */
struct SharedClockWeather: Sendable {
  let cityKey: String
  let temperature: Double
  let code: Int
  let isDay: Bool
  let fetchedAt: Date
  let high: Double?
  let low: Double?

  var symbol: String {
    switch code {
    case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
    case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case 3: return "cloud.fill"
    case 45, 48: return "cloud.fog.fill"
    case 51...67, 80...82: return "cloud.rain.fill"
    case 71...77, 85, 86: return "cloud.snow.fill"
    case 95...99: return "cloud.bolt.rain.fill"
    default: return "cloud.fill"
    }
  }
  var label: String {
    switch code {
    case 0: return "晴"
    case 1, 2: return "晴间多云"
    case 3: return "阴"
    case 45, 48: return "雾"
    case 51...57: return "毛毛雨"
    case 61...67, 80...82: return "雨"
    case 71...77, 85, 86: return "雪"
    case 95...99: return "雷雨"
    default: return "天气"
    }
  }
  func stale(at date: Date) -> Bool { date.timeIntervalSince(fetchedAt) > 2700 }

  static func decode(_ raw: String?) -> SharedClockWeather? {
    guard let raw = raw, let data = raw.data(using: .utf8), data.count <= 131072,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let city = json["cityKey"] as? String,
          let temperature = json["temperature"] as? NSNumber, temperature.doubleValue.isFinite,
          let code = json["code"] as? NSNumber, (0...99).contains(code.intValue),
          let stamp = json["fetchedAt"] as? String, let date = parseDate(stamp) else { return nil }
    func optionalNumber(_ key: String) -> Double? {
      guard let number = json[key] as? NSNumber, number.doubleValue.isFinite else { return nil }
      return number.doubleValue
    }
    return SharedClockWeather(cityKey: city, temperature: temperature.doubleValue, code: code.intValue,
      isDay: json["isDay"] as? Bool ?? true, fetchedAt: date,
      high: optionalNumber("high"), low: optionalNumber("low"))
  }

  private static func parseDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: value) { return date }
    // 兼容此前 Flutter 按本地时区写入、未附 Z 的缓存；新数据一律写 UTC。
    let legacy = DateFormatter(); legacy.locale = Locale(identifier: "en_US_POSIX")
    for pattern in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
      legacy.dateFormat = pattern
      if let date = legacy.date(from: value) { return date }
    }
    return nil
  }

  func encoded() -> String? {
    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var value: [String: Any] = ["cityKey": cityKey, "temperature": temperature, "code": code,
      "isDay": isDay, "fetchedAt": formatter.string(from: fetchedAt)]
    if let high = high { value["high"] = high }; if let low = low { value["low"] = low }
    guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

/** App 与扩展分别运行，使用 App Group 的原子文件与不可变 JSON 快照共享状态。 */
enum ClockWidgetStore {
  static let appGroup = "group.com.xiongjian.widget"
  static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) }
  static var defaults: UserDefaults? { container == nil ? nil : UserDefaults(suiteName: appGroup) }
  enum SettingsFailure: Error { case appGroupUnavailable, invalidPayload }

  /** 每次读取已原子提交的文件，避免扩展进程保留 UserDefaults 的旧尺寸缓存。 */
  static func settings(in directory: URL? = ClockWidgetStore.container) -> SharedClockSettings {
    if let url = directory?.appendingPathComponent("clock-settings.json"),
       let data = try? Data(contentsOf: url), data.count <= 131072,
       let raw = String(data: data, encoding: .utf8) {
      return SharedClockSettings(raw: raw)
    }
    return SharedClockSettings(raw: defaults?.string(forKey: "widget.settings"))
  }

  /** 调用方串行提交底图后再提交设置；只有完成此操作才可请求小组件重载。 */
  static func writeSettings(_ raw: String, in directory: URL? = ClockWidgetStore.container) throws {
    guard let data = raw.data(using: .utf8), data.count <= 131072,
          (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else {
      throw SettingsFailure.invalidPayload
    }
    guard let directory = directory else { throw SettingsFailure.appGroupUnavailable }
    try data.write(to: directory.appendingPathComponent("clock-settings.json"), options: .atomic)
  }
  static func weather(for settings: SharedClockSettings) -> SharedClockWeather? {
    ["widget.weather", "widget.extensionWeather"].compactMap { SharedClockWeather.decode(defaults?.string(forKey: $0)) }
      .filter { $0.cityKey == settings.cityKey }.max { $0.fetchedAt < $1.fetchedAt }
  }
  static func dialURL(scale: Double, moving: Bool = false) -> URL? {
    guard scale.isFinite else { return nil }
    return container?.appendingPathComponent("\(moving ? "motion-dial" : "dial")-\(Int((min(1.5, max(0.5, scale)) * 1000).rounded())).png")
  }
}

/** 日历与月相预生成 24 小时节点；动态机械指针独立由 WidgetKit 的系统时间驱动。 */
enum ClockTimelineSchedule {
  static func dates(from now: Date) -> [Date] {
    let start = floor(now.timeIntervalSince1970 / 300) * 300
    // 预留整天节点。系统延迟重载时日历/月相仍有后续值，指针动画独立由系统驱动。
    return [now] + (1...289).map { Date(timeIntervalSince1970: start + Double($0) * 300) }
  }
}
