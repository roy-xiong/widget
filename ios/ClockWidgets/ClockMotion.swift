import Foundation
import SwiftUI
import UIKit
import WidgetKit

/** 可失败的能力检测；不依赖内存布局。失败时由表盘显示定时指针和明确提示。 */
enum ClockMotionRuntime {
  static let available: Bool = {
    guard let type = _typeByName("9WidgetKit24_ClockHandRotationEffectV") as? any Decodable.Type,
          let data = try? JSONEncoder().encode(_ClockHandData(period: 60, timeZone: .current, anchor: .center)),
          let decoded = try? JSONDecoder().decode(type, from: data),
          decoded is any ViewModifier else { return false }
    return true
  }()
}

/** 与 App 的 60 秒笼架和 8 Hz 量化摆轮一致。摆轮每 0.25 秒完成一次正、反摆。 */
enum ClockMotionTiming {
  static let cagePeriod: Double = 60
  static let balancePeriod: Double = 0.25
  static let beatInterval: Double = 0.125
  static let designSide: CGFloat = 360
  static let dialRadius: CGFloat = 165.44
  static let mechanismSide = dialRadius * 0.49
  static let mechanismOffset = dialRadius * 0.45

  /** 固定日期只用于可重放的云端渲染；正式小组件始终由系统的绝对时间驱动。 */
  static func turns(at date: Date, period: Double, zone: TimeZone) -> Double {
    let seconds = date.timeIntervalSince1970 + Double(zone.secondsFromGMT(for: date))
    let cycles = seconds / period
    return cycles - floor(cycles)
  }
  static func balanceFrame(at date: Date) -> Int {
    Int(floor(date.timeIntervalSince1970 / beatInterval)).quotientAndRemainder(dividingBy: 2).remainder == 0 ? 0 : 1
  }
}

/** 资源完全由 App 的正式 Flutter 画笔导出；探针可注入同一批 PNG 做像素对照。 */
struct ClockMotionArtwork {
  static let names = ["MotionHourHand", "MotionMinuteHand", "MotionSecondHand", "MotionPin",
    "TourbillonRim", "TourbillonPositive", "TourbillonNegative"]
  static let bundled = ClockMotionArtwork()
  private let images: [String: UIImage]

  init(directory: URL? = nil) {
    var loaded: [String: UIImage] = [:]
    for name in Self.names {
      let image = directory.flatMap { UIImage(contentsOfFile: $0.appendingPathComponent(name + ".png").path) }
        ?? UIImage(named: name)
      if let image = image { loaded[name] = image }
    }
    images = loaded
  }
  var complete: Bool { images.count == Self.names.count }
  func image(_ name: String) -> Image {
    if let image = images[name] { return Image(uiImage: image) }
    return Image(name)
  }
}

/** 时、分、秒针保持 App 的轮廓、钢针切面、描边、阴影与轴心，不在 SwiftUI 中重画近似图形。 */
struct LiveMechanicalMotion: View {
  var renderDate: Date? = nil
  var timeZone: TimeZone = .current
  var artwork: ClockMotionArtwork = .bundled

  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ZStack {
        LiveTourbillon(renderDate: renderDate, artwork: artwork)
          .frame(width: ClockMotionTiming.mechanismSide, height: ClockMotionTiming.mechanismSide)
          .offset(y: ClockMotionTiming.mechanismOffset)
        hand("MotionHourHand", period: .hourHand)
        hand("MotionMinuteHand", period: .minuteHand)
        hand("MotionSecondHand", period: .secondHand)
        artwork.image("MotionPin").resizable().frame(width: 360, height: 360)
      }.frame(width: 360, height: 360)
        .scaleEffect(side / 360).frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
  private func hand(_ name: String, period: ClockHandPeriod) -> some View {
    artwork.image(name).resizable().frame(width: 360, height: 360)
      .modifier(ClockArtworkRotation(period: period, zone: timeZone, renderDate: renderDate))
  }
}

/** 固定框保持静止；机芯每分钟一圈；两张真实摆轮帧按每秒八次交替，禁止用慢速整图旋转代替。 */
struct LiveTourbillon: View {
  var renderDate: Date? = nil
  var artwork: ClockMotionArtwork = .bundled
  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ZStack {
        artwork.image("TourbillonRim").resizable()
        ZStack {
          ForEach(0..<2) { index in
            artwork.image(index == 0 ? "TourbillonPositive" : "TourbillonNegative")
              .resizable().frame(width: side, height: side)
              .mask {
                // 大半径弧形遮罩以固定视口切换帧，不绕着表盘公转，也不移动图片本身。
                // 思路参考 ClockHandKit 的 Frame animation，只有两帧以控制扩展的解码内存。
                BalanceFrameMask(index: index, radius: side * 50)
                  .stroke(style: StrokeStyle(lineWidth: side * 1.5, lineCap: .butt))
                  .frame(width: side, height: side)
                  .modifier(ClockArtworkRotation(period: .custom(ClockMotionTiming.balancePeriod), zone: .gmt, renderDate: renderDate))
                  .offset(y: side * 50)
              }
          }
        }.frame(width: side, height: side)
          .modifier(ClockArtworkRotation(period: .custom(ClockMotionTiming.cagePeriod), zone: .gmt, renderDate: renderDate))
      }.frame(width: side, height: side)
    }
  }
}

/** 相邻半圆无间隙，0～125 ms 显示正摆，125～250 ms 显示反摆，之后按绝对时间重复。 */
struct BalanceFrameMask: Shape {
  let index: Int
  let radius: CGFloat
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
      startAngle: .degrees(-90 - Double(index + 1) * 180),
      endAngle: .degrees(-90 - Double(index) * 180), clockwise: false)
    return path
  }
}

/** 同一生产视图支持固定日期回放，云端可验证最终图层、转轴、相位，而非只检查 API 能否解码。 */
struct ClockArtworkRotation: ViewModifier {
  let period: ClockHandPeriod
  let zone: TimeZone
  let renderDate: Date?
  func body(content: Content) -> some View {
    if let date = renderDate {
      content.rotationEffect(.radians(ClockMotionTiming.turns(at: date, period: period.duration, zone: zone) * .pi * 2))
    } else {
      content.clockHandRotationEffect(period: period, in: zone)
    }
  }
}
