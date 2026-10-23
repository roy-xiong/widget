import Foundation

/** 云端原生测试入口：校验 Flutter JSON 兼容、尺寸边界、时间线和真实 URLSession 错误分支。 */
final class WeatherFixtureProtocol: URLProtocol {
  static var responseStatus = 200
  static var responseData = Data()
  static var responseError: Error?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    if let error = Self.responseError { client?.urlProtocol(self, didFailWithError: error); return }
    guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: Self.responseStatus,
      httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else { return }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.responseData)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

func validateModels() {
  let defaults = SharedClockSettings(raw: "{}")
  precondition(defaults.moonScale == 1 && defaults.calendarScale == 1 && defaults.romanScale == 1)
  let custom = SharedClockSettings(raw: #"{"moonScale":0.1,"calendarScale":4,"romanScale":1.25,"city":{"name":"上海","latitude":31.2304,"longitude":121.4737}}"#)
  precondition(custom.moonScale == 0.5 && custom.calendarScale == 1.5 && custom.romanScale == 1.25)
  precondition(custom.cityKey == "31.2304,121.4737")
  let invalid = SharedClockSettings(raw: #"{"city":{"name":"bad","latitude":999,"longitude":0}}"#)
  precondition(invalid.cityName == "北京")
  precondition(SharedClockSettings(raw: "[not json").romanScale == 1)
  let date = Date(timeIntervalSince1970: 1712600460)
  let weather = SharedClockWeather(cityKey: custom.cityKey, temperature: 20, code: 2, isDay: true,
    fetchedAt: date, high: 25, low: 15)
  let restored = SharedClockWeather.decode(weather.encoded())
  precondition(restored?.cityKey == custom.cityKey && restored?.temperature == 20)
  precondition(restored?.fetchedAt == date)
  precondition(weather.stale(at: date.addingTimeInterval(2701)))
  precondition(!weather.stale(at: date.addingTimeInterval(200)))
  precondition(SharedClockWeather.decode("{}") == nil)
  precondition(SharedClockWeather.decode(#"{"cityKey":"a","temperature":20,"code":2,"fetchedAt":"2026-10-23T10:15:23.123456"}"#) != nil)
  for timestamp in [0.0, 1712600460, 1792713599, 1792713600] {
    let now = Date(timeIntervalSince1970: timestamp)
    let dates = ClockTimelineSchedule.dates(from: now)
    precondition(dates.count == 13 && dates.first == now)
    precondition(dates[1] > now)
    for index in 2..<dates.count { precondition(dates[index].timeIntervalSince(dates[index - 1]) == 300) }
  }
}

func validateNetwork() async throws {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [WeatherFixtureProtocol.self]
  let session = URLSession(configuration: configuration)
  defer { session.invalidateAndCancel() }
  let client = ClockWeatherClient(session: session), settings = SharedClockSettings()
  WeatherFixtureProtocol.responseData = Data(#"{"current":{"temperature_2m":18.5,"weather_code":2,"is_day":1},"daily":{"temperature_2m_max":[23],"temperature_2m_min":[null]}}"#.utf8)
  let result = try await client.fetch(settings)
  precondition(result.temperature == 18.5 && result.high == 23 && result.low == nil)
  precondition(result.cityKey == settings.cityKey)
  WeatherFixtureProtocol.responseStatus = 503
  do { _ = try await client.fetch(settings); fatalError("503 must fail") }
  catch ClockWeatherClient.Failure.invalidResponse {}
  WeatherFixtureProtocol.responseStatus = 200
  WeatherFixtureProtocol.responseData = Data("not JSON".utf8)
  do { _ = try await client.fetch(settings); fatalError("Malformed JSON must fail") }
  catch is DecodingError {}
  WeatherFixtureProtocol.responseError = URLError(.notConnectedToInternet)
  do { _ = try await client.fetch(settings); fatalError("Offline must fail") }
  catch let error as URLError { precondition(error.code == .notConnectedToInternet) }
  WeatherFixtureProtocol.responseError = nil
  WeatherFixtureProtocol.responseData = Data(repeating: 65, count: 65537)
  do { _ = try await client.fetch(settings); fatalError("Oversized payload must fail") }
  catch ClockWeatherClient.Failure.invalidPayload {}
}

@main
struct WidgetRegressionMain {
  static func main() async throws {
    validateModels()
    try await validateNetwork()
    print("Widget model and networking regressions passed")
  }
}
