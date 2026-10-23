import Foundation

/** 直接驱动正式时间线计划：模拟系统延迟重载，检查跨小时及跨夜后表针是否仍有有效节点。 */
@main
struct WidgetTimelineRegression {
  static func main() {
    var failures: [String] = []
    let start = Date(timeIntervalSince1970: 1792742398)
    let dates = ClockTimelineSchedule.dates(from: start)
    for elapsed in [0.0, 299, 3601, 3 * 3600, 8 * 3600, 23 * 3600] {
      let now = start.addingTimeInterval(elapsed)
      let selected = dates.last(where: { $0 <= now }) ?? start
      let age = now.timeIntervalSince(selected)
      print("Elapsed \(Int(elapsed))s: selected entry age \(Int(age))s")
      if age >= 300 { failures.append("At +\(Int(elapsed / 3600))h, clock is \(Int(age)) seconds behind") }
    }
    let horizon = dates.last?.timeIntervalSince(start) ?? 0
    if horizon < 86400 { failures.append("Timeline ends after \(Int(horizon))s; expected at least one day of fallback entries") }
    if !failures.isEmpty {
      failures.forEach { print("FAIL: \($0)") }
      exit(1)
    }
    print("Widget delayed-reload clock regression passed")
  }
}
