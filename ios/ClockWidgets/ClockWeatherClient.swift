import Foundation

/** 小组件独立获取天气，App 未运行时仍可更新；注入会话以支持离线与错误响应验证。 */
struct ClockWeatherClient {
  let session: URLSession
  static func live() -> ClockWeatherClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 8
    configuration.timeoutIntervalForResource = 12
    configuration.waitsForConnectivity = false
    return ClockWeatherClient(session: URLSession(configuration: configuration))
  }
  enum Failure: Error { case invalidURL, invalidResponse, invalidPayload }

  func fetch(_ settings: SharedClockSettings) async throws -> SharedClockWeather {
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [URLQueryItem(name: "latitude", value: String(settings.latitude)),
      URLQueryItem(name: "longitude", value: String(settings.longitude)),
      URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
      URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
      URLQueryItem(name: "forecast_days", value: "1"), URLQueryItem(name: "timezone", value: "auto")]
    guard let url = components?.url else { throw Failure.invalidURL }
    let (bytes, response) = try await session.bytes(for: URLRequest(url: url))
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw Failure.invalidResponse }
    var data = Data()
    for try await byte in bytes {
      try Task.checkCancellation()
      guard data.count < 65536 else { throw Failure.invalidPayload }
      data.append(byte)
    }
    return try Self.decode(data, settings: settings)
  }

  static func decode(_ data: Data, settings: SharedClockSettings) throws -> SharedClockWeather {
    struct Payload: Decodable {
      struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let is_day: Int }
      struct Daily: Decodable { let temperature_2m_max: [Double?]?; let temperature_2m_min: [Double?]? }
      let current: Current
      let daily: Daily?
    }
    let value = try JSONDecoder().decode(Payload.self, from: data)
    guard value.current.temperature_2m.isFinite, (0...99).contains(value.current.weather_code) else { throw Failure.invalidPayload }
    return SharedClockWeather(cityKey: settings.cityKey, temperature: value.current.temperature_2m,
      code: value.current.weather_code, isDay: value.current.is_day != 0, fetchedAt: Date(),
      high: value.daily?.temperature_2m_max?.first ?? nil, low: value.daily?.temperature_2m_min?.first ?? nil)
  }
}
