import Foundation
import SwiftUI
import WidgetKit

/** 云端模拟器真实运行时检测，不把源码包含字段或仅编译成功当成动态效果可用。 */
@main
struct WidgetMotionProbe {
  @MainActor static func main() throws {
    print("Runtime:", ProcessInfo.processInfo.operatingSystemVersionString)
    let periods: [(ClockHandPeriod, Double)] = [(.hourHand, 43200), (.minuteHand, 3600), (.secondHand, 60), (.custom(60), 60)]
    for (period, duration) in periods {
      let bytes = try JSONEncoder().encode(_ClockHandData(period: period.duration, timeZone: .current, anchor: .center))
      let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
      precondition(json?["period"] as? Double == duration)
      precondition(json?["honorIdealizedDate"] as? Bool == false)
      precondition(json?["anchor"] as? [Double] == [0.5, 0.5])
      guard let type = _typeByName("9WidgetKit24_ClockHandRotationEffectV") as? any Decodable.Type else {
        print("FAIL: WidgetKit runtime effect is missing"); exit(2)
      }
      let effect = try JSONDecoder().decode(type, from: bytes)
      precondition(effect is any ViewModifier, "Runtime effect must conform to ViewModifier")
      print("Decoded real WidgetKit rotation: \(duration)s")
    }
    precondition(ClockMotionRuntime.available)
    print("PASS: real runtime type lookup, all four periods and iOS 27 payload decoded")
    print("This proves runtime construction only; Home Screen animation still needs device verification.")
  }
}
