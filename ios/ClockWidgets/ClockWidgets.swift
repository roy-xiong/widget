import SwiftUI
import WidgetKit

/** 扩展不启动 Flutter 引擎，两种小组件可同时添加；共享 App 的城市及组件尺寸。 */
@main
struct DesktopClockWidgetBundle: WidgetBundle {
  var body: some Widget { MechanicalClockWidget(); ManilaClockWidget() }
}

struct ClockEntry: TimelineEntry {
  let date: Date
  let settings: SharedClockSettings
  let weather: SharedClockWeather?
}

/** 只在系统请求时间线时执行网络任务；失败保留缓存，并与五分钟表盘节点分开。 */
struct ClockProvider: TimelineProvider {
  func placeholder(in context: Context) -> ClockEntry {
    ClockEntry(date: Date(), settings: SharedClockSettings(), weather: nil)
  }
  func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
    let settings = ClockWidgetStore.settings()
    completion(ClockEntry(date: Date(), settings: settings, weather: ClockWidgetStore.weather(for: settings)))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
    Task {
      let requestedSettings = ClockWidgetStore.settings()
      var weather = ClockWidgetStore.weather(for: requestedSettings)
      if weather == nil || Date().timeIntervalSince(weather?.fetchedAt ?? .distantPast) > 900 {
        let client = ClockWeatherClient.live()
        defer { client.session.invalidateAndCancel() }
        if let fresh = try? await client.fetch(requestedSettings) {
          weather = fresh
          // 城市可能在请求期间被 App 更改；旧结果仅属于自己的城市，不能写成新城市天气。
          if ClockWidgetStore.settings().cityKey == fresh.cityKey {
            ClockWidgetStore.defaults?.set(fresh.encoded(), forKey: "widget.extensionWeather")
          }
        }
      }
      // 天气请求期间滑杆可能已变化：生成时间线前重读文件，禁止旧快照覆盖用户的新尺寸。
      let settings = ClockWidgetStore.settings()
      if settings.cityKey != requestedSettings.cityKey {
        weather = ClockWidgetStore.weather(for: settings)
      }
      let dates = ClockTimelineSchedule.dates(from: Date())
      let entries = dates.map { ClockEntry(date: $0, settings: settings, weather: weather) }
      // 天气按半小时请求更新，日历/月相保留 24 小时备用节点；两者均不驱动秒针。
      completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(1800))))
    }
  }
}

struct MechanicalClockWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "MechanicalClock", provider: ClockProvider()) { entry in
      MechanicalWidgetView(entry: entry)
        .containerBackground(for: .widget) { Color(red: 0.06, green: 0.09, blue: 0.12) }
    }
    .configurationDisplayName("机械月相时钟")
    .description("实验动态表盘：系统驱动时、分、秒针和陀飞轮，保留月相与星期日历。")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}

struct ManilaClockWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ManilaClock", provider: ClockProvider()) { entry in
      GeometryReader { geometry in
        let scale = min((geometry.size.width - 12) / 360, (geometry.size.height - 6) / 250)
        ManilaWidgetView(entry: entry)
          .frame(width: 360, height: 250).scaleEffect(scale)
          .frame(width: geometry.size.width, height: geometry.size.height)
      }
      .containerBackground(for: .widget) {
        LinearGradient(colors: [Color(red: 0.12, green: 0.21, blue: 0.28), Color(red: 0.08, green: 0.10, blue: 0.16)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      }
    }
    .configurationDisplayName("马尼拉天气时钟")
    .description("经典翻页牌外观，小时和分钟由系统自动更新，天气使用 App 中选择的城市。")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}

/** 使用 iOS 18+ 的公开 TimeDataSource，避免把时间固定成时间线生成时的字符串。 */
struct LiveClockText: View {
  var part: String = "time"
  var body: some View {
    Group {
      if part == "hour" {
        Text(.currentDate, format: Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).locale(Locale(identifier: "en_GB")))
      } else if part == "minute" {
        Text(.currentDate, format: Date.FormatStyle().minute(.twoDigits).locale(Locale(identifier: "en_GB")))
      } else {
        Text(.currentDate, format: Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB")))
      }
    }.monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
  }
}

struct MechanicalWidgetView: View {
  let entry: ClockEntry
  @Environment(\.widgetFamily) private var family
  var body: some View {
    GeometryReader { geometry in
      let medium = family == .systemMedium
      let diameter = min(geometry.size.height - 10, medium ? geometry.size.width * 0.49 : geometry.size.width - 10)
      HStack(spacing: 8) {
        VStack(spacing: 0) {
          NativeMechanicalFace(entry: entry).frame(width: diameter, height: diameter)
            .accessibilityLabel("机械表盘，系统实时驱动指针")
        }
        if medium {
          VStack(alignment: .leading, spacing: 6) {
            Text(entry.date, format: .dateTime.month().day().weekday()).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
            WidgetWeather(entry: entry)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      }.overlay(alignment: .bottom) {
        if !ClockMotionRuntime.available {
          Text("动态效果不可用").font(.system(size: 9)).foregroundStyle(.orange)
        }
      }.padding(.horizontal, 5).frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

/** 小组件天气没有虚构占位值；离线数据注明旧缓存，点击组件直接进入 App 设置。 */
struct WidgetWeather: View {
  let entry: ClockEntry
  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(entry.settings.cityName).font(.system(size: 12)).lineLimit(1)
      if let weather = entry.weather {
        Label("\(Int(weather.temperature.rounded()))°  \(weather.label)", systemImage: weather.symbol)
          .font(.system(size: 12)).symbolRenderingMode(.multicolor).lineLimit(1)
        Text(weather.stale(at: entry.date) ? "上次天气 · Open-Meteo" : "Open-Meteo")
          .font(.system(size: 8)).foregroundStyle(.secondary)
      } else {
        Text("天气暂不可用").font(.system(size: 11)).foregroundStyle(.secondary)
        Text("Open-Meteo").font(.system(size: 8)).foregroundStyle(.secondary)
      }
    }.foregroundStyle(.white)
  }
}

struct ManilaWidgetView: View {
  let entry: ClockEntry
  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 9).fill(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.35), lineWidth: 0.7))
        .frame(width: 360, height: 214).offset(y: 16)
      NativeFlipCard(part: "hour").frame(width: 142, height: 164).offset(x: 20)
      NativeFlipCard(part: "minute").frame(width: 142, height: 164).offset(x: 198)
      VStack(alignment: .leading, spacing: 5) {
        Text(entry.settings.cityName).font(.system(size: 13))
        Text(entry.weather?.label ?? "暂无天气").font(.system(size: 12))
      }.lineLimit(1).frame(width: 112, alignment: .leading).offset(x: 12, y: 180)
      Image(systemName: entry.weather?.symbol ?? "cloud")
        .symbolRenderingMode(.multicolor).resizable().scaledToFit()
        .frame(width: 102, height: 70).offset(x: 129, y: 163)
      VStack(alignment: .trailing, spacing: 3) {
        Text(entry.date, format: .dateTime.month().day().weekday()).font(.system(size: 11))
        HStack(spacing: 5) {
          Text(entry.weather.map { "\(Int($0.temperature.rounded()))°" } ?? "—°").font(.system(size: 31, weight: .light))
          VStack(alignment: .trailing) {
            Text("高 \(entry.weather?.high.map { String(Int($0.rounded())) } ?? "—")°")
            Text("低 \(entry.weather?.low.map { String(Int($0.rounded())) } ?? "—")°")
          }.font(.system(size: 10))
        }
      }.frame(width: 110, alignment: .trailing).offset(x: 238, y: 177)
      Text(entry.weather?.stale(at: entry.date) == true ? "上次天气 · Open-Meteo" : "Open-Meteo")
        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.65)).offset(x: 12, y: 235)
    }.frame(width: 360, height: 250).foregroundStyle(.white)
  }
}

/** 保留翻页牌折缝和玻璃外观；系统动态文本更新不伪装成受保证的三维翻页动画。 */
struct NativeFlipCard: View {
  let part: String
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(LinearGradient(
        colors: [Color(white: 0.98), Color(white: 0.88), Color(white: 0.98)], startPoint: .top, endPoint: .bottom))
      LiveClockText(part: part).font(.system(size: 139, weight: .light)).foregroundStyle(Color(white: 0.14))
        .frame(width: 125, height: 158).clipped()
      Rectangle().fill(.black.opacity(0.35)).frame(height: 0.8)
      HStack { Capsule().frame(width: 2.5, height: 7); Spacer(); Capsule().frame(width: 2.5, height: 7) }
        .foregroundStyle(.gray)
    }.shadow(color: .black.opacity(0.4), radius: 3, y: 3)
  }
}
