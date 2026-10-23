import Foundation
import SwiftUI
import WidgetKit
import UIKit

/** 探针只编译生产表盘，不包含带 @main 的 WidgetBundle；数据结构与正式 TimelineEntry 一致。 */
struct ClockEntry {
  let date: Date
  let settings: SharedClockSettings
  let weather: SharedClockWeather?
}

/** 云端模拟器真实运行时检测，不把源码包含字段或仅编译成功当成动态效果可用。 */
@main
struct WidgetMotionProbe {
  @MainActor static func main() throws {
    setbuf(stdout, nil)
    if CommandLine.arguments.contains("--render-app") {
      UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(WidgetMotionProbeDelegate.self))
      return
    }
    print("Runtime:", ProcessInfo.processInfo.operatingSystemVersionString)
    // import 不一定产生运行时链接引用；真实扩展由 WidgetKit 宿主加载，探针显式加载同一框架。
    print("WidgetKit loaded:", String(reflecting: type(of: WidgetCenter.shared)))
    if let type = _typeByName("9WidgetKit24_ClockHandRotationEffectV") {
      print("Resolved effect type:", String(reflecting: type))
    }
    let periods: [(ClockHandPeriod, Double)] = [(.hourHand, 43200), (.minuteHand, 3600), (.secondHand, 60), (.custom(60), 60), (.custom(0.25), 0.25)]
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
    print("PASS: real runtime type lookup, clock/cage/balance periods and iOS 27 payload decoded")
    print("Runtime construction and fixed-date rendering are verified; live iOS 27 cadence still needs device verification.")
  }

  /** 渲染正式 SwiftUI 活动层，与 Flutter 正式画笔在同一时刻的输出逐像素对照。 */
  @MainActor static func validateArtwork(directory: URL, output: URL) throws {
    let artwork = ClockMotionArtwork(directory: directory)
    precondition(artwork.complete, "All canonical App layers must be present")
    let data = try Data(contentsOf: directory.appendingPathComponent("timing.json"))
    guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let samples = manifest["samples"] as? [[String: Any]] else { fatalError("Invalid artwork manifest") }
    precondition(manifest["cagePeriod"] as? Double == ClockMotionTiming.cagePeriod)
    precondition(manifest["balancePeriod"] as? Double == ClockMotionTiming.balancePeriod)
    precondition(manifest["beatInterval"] as? Double == ClockMotionTiming.beatInterval)
    for sample in samples {
      guard let epoch = sample["epoch"] as? Double, let file = sample["file"] as? String,
            let reference = UIImage(contentsOfFile: directory.appendingPathComponent(file).path)?.cgImage else {
        fatalError("Missing reference frame")
      }
      let date = Date(timeIntervalSince1970: epoch)
      print("Rendering production widget artwork:", file)
      let view = LiveMechanicalMotion(renderDate: date, timeZone: .gmt, artwork: artwork).frame(width: 360, height: 360)
      let renderer = ImageRenderer(content: view)
      renderer.scale = 2
      guard let image = renderer.uiImage, let actual = image.cgImage, let png = image.pngData() else {
        fatalError("Production motion view did not render")
      }
      try png.write(to: output.appendingPathComponent("native-" + file))
      let expectedBytes = pixels(reference), actualBytes = pixels(actual)
      precondition(expectedBytes.count == actualBytes.count)
      var ink = 0, difference = 0, overlapping = 0, expectedInk = 0
      for pixel in stride(from: 0, to: expectedBytes.count, by: 4) {
        let expectedAlpha = Int(expectedBytes[pixel + 3]), actualAlpha = Int(actualBytes[pixel + 3])
        if expectedAlpha > 24 { expectedInk += 1 }
        if expectedAlpha > 24 && actualAlpha > 24 { overlapping += 1 }
        if max(expectedAlpha, actualAlpha) > 24 {
          ink += 1
          for channel in 0..<4 { difference += abs(Int(expectedBytes[pixel + channel]) - Int(actualBytes[pixel + channel])) }
        }
      }
      let mean = Double(difference) / Double(max(1, ink) * 4)
      let overlap = Double(overlapping) / Double(max(1, expectedInk))
      print("ARTWORK \(file): mean ink delta=\(mean), overlap=\(overlap), balance frame=\(ClockMotionTiming.balanceFrame(at: date))")
      precondition(overlap > 0.92, "Hand/mechanism placement differs from App")
      precondition(mean < 18, "Hand UI or tourbillon phase differs from App")
    }
    print("PASS: production widget hands, fixed rim and 8 Hz balance match App reference frames")
    try validateComponentSizes(directory: directory, output: output, artwork: artwork)
  }

  /** 从正式共享文件读取设置，再渲染正式小组件表盘，验证三个滑杆各自能改变其对应区域。 */
  @MainActor static func validateComponentSizes(directory: URL, output: URL, artwork: ClockMotionArtwork) throws {
    let shared = output.appendingPathComponent("shared-settings-test")
    try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: shared) }
    var baseline: [UInt8]?
    let date = Date(timeIntervalSince1970: 1767262118.141)
    let cases: [(String, String, String, CGRect?)] = [
      ("baseline", "{}", "dial-roman-1000.png", nil),
      ("moon", #"{"moonScale":1.5}"#, "dial-roman-1000.png", CGRect(x: 115, y: 72, width: 130, height: 80)),
      ("calendar", #"{"calendarScale":1.5}"#, "dial-roman-1000.png", CGRect(x: 170, y: 145, width: 145, height: 70)),
      ("roman", #"{"romanScale":1.5}"#, "dial-roman-1500.png", CGRect(x: 145, y: 30, width: 70, height: 45)),
    ]
    for (name, raw, dialName, region) in cases {
      try ClockWidgetStore.writeSettings(raw, in: shared)
      let settings = ClockWidgetStore.settings(in: shared)
      precondition(settings == SharedClockSettings(raw: raw))
      let entry = ClockEntry(date: date, settings: settings, weather: nil)
      let dial = UIImage(contentsOfFile: directory.appendingPathComponent(dialName).path)
      precondition(dial != nil)
      let view = NativeMechanicalFace(entry: entry, renderDate: date, artwork: artwork, dialImage: dial)
        .frame(width: 360, height: 360)
      let renderer = ImageRenderer(content: view); renderer.scale = 2
      guard let image = renderer.uiImage, let cgImage = image.cgImage, let png = image.pngData() else {
        fatalError("Cannot render component size case")
      }
      try png.write(to: output.appendingPathComponent("component-" + name + ".png"))
      let bytes = pixels(cgImage)
      if let baseline = baseline, let region = region {
        var changed = 0
        for y in Int(region.minY * 2)..<Int(region.maxY * 2) {
          for x in Int(region.minX * 2)..<Int(region.maxX * 2) {
            let pixel = (y * cgImage.width + x) * 4
            if (0..<4).contains(where: { abs(Int(bytes[pixel + $0]) - Int(baseline[pixel + $0])) > 16 }) { changed += 1 }
          }
        }
        print("COMPONENT \(name): changed pixels in its own region=\(changed)")
        precondition(changed > 200, "Component slider has no effect in the production widget")
      } else { baseline = bytes }
    }
    print("PASS: moon/calendar/Roman sizes survive file sharing and change production widget pixels")
  }

  /** 统一 PNG/SwiftUI 的颜色通道和像素坐标，避免图片内部 BGRA 排列造成误判。 */
  static func pixels(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Cannot allocate pixel context") }
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
  }
}

/** SwiftUI ImageRenderer 在真实 UIApplication 的图形环境中执行，避免把 CLI 框架解码误当成画面验证。 */
@MainActor
final class WidgetMotionProbeDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = UIViewController()
    window.makeKeyAndVisible()
    self.window = window
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      do {
        guard let resources = Bundle.main.resourceURL,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
          fatalError("Missing probe resources")
        }
        try WidgetMotionProbe.validateArtwork(directory: resources.appendingPathComponent("widget-artwork"), output: documents)
        print("ARTWORK_RENDER_PASS")
        exit(0)
      } catch {
        print("ARTWORK_RENDER_FAIL:", error)
        exit(2)
      }
    }
    return true
  }
}
