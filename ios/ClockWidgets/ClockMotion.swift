import Foundation
import SwiftUI
import WidgetKit

/**
 * 实验系统动画能力检测，与固定版本 ClockHandKit 使用同一负载。
 * 只通过可失败的类型转换构建效果，不假定内存布局；失败时保留定时表针和明确提示。
 */
enum ClockMotionRuntime {
  static let available: Bool = {
    guard let type = _typeByName("9WidgetKit24_ClockHandRotationEffectV") as? any Decodable.Type,
          let data = try? JSONEncoder().encode(_ClockHandData(period: 60, timeZone: .current, anchor: .center)),
          let decoded = try? JSONDecoder().decode(type, from: data),
          decoded is any ViewModifier else { return false }
    return true
  }()
}

/** 时分秒各由 WidgetKit 的真实系统时钟驱动；不读取五分钟节点的 entry.date 来旋转。 */
struct LiveMechanicalMotion: View {
  private let steel = LinearGradient(colors: [Color(red: 0.03, green: 0.09, blue: 0.18),
    Color(red: 0.15, green: 0.31, blue: 0.48), Color(red: 0.55, green: 0.71, blue: 0.82),
    Color(red: 0.09, green: 0.24, blue: 0.41), Color(red: 0.02, green: 0.07, blue: 0.15)],
    startPoint: .leading, endPoint: .trailing)

  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ZStack {
        // 单独旋转陀飞轮笼架；图片的边界就是其自身转轴，不能绕整张表盘公转。
        ZStack {
          Circle().fill(AngularGradient(colors: [.gray, .white, .gray, Color(white: 0.8), .gray], center: .center))
          Image("MotionTourbillon").resizable().scaledToFit()
            .frame(width: 81.0656, height: 81.0656)
            .clipShape(Circle().inset(by: 3.5))
            .clockHandRotationEffect(period: .custom(60), in: .gmt)
        }.frame(width: 81.0656, height: 81.0656).offset(y: 74.448)
        LiveLeafHand(length: 0.70, halfWidth: 0.044).fill(steel)
          .clockHandRotationEffect(period: .hourHand, in: .current)
        LiveLeafHand(length: 0.94, halfWidth: 0.028).fill(steel)
          .clockHandRotationEffect(period: .minuteHand, in: .current)
        LiveSecondHand().stroke(Color(red: 0.09, green: 0.24, blue: 0.41),
          style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
          .clockHandRotationEffect(period: .secondHand, in: .current)
        Circle().fill(RadialGradient(colors: [.white, Color(red: 0.27, green: 0.35, blue: 0.42)],
          center: .topLeading, startRadius: 0, endRadius: 18)).frame(width: 19.2, height: 19.2)
        Circle().fill(Color(red: 0.04, green: 0.16, blue: 0.30)).frame(width: 8.3, height: 8.3)
      }.frame(width: 360, height: 360)
        .scaleEffect(side / 360).frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

/** 保持与 Flutter 表盘相同的叶形蓝钢针比例，初始朝 XII，以表盘正中为转轴。 */
struct LiveLeafHand: Shape {
  let length: CGFloat
  let halfWidth: CGFloat
  func path(in rect: CGRect) -> Path {
    let r: CGFloat = 165.44, tip = r * length, width = r * halfWidth, tail = r * 0.09
    var path = Path(); path.move(to: CGPoint(x: 0, y: -tip))
    path.addQuadCurve(to: CGPoint(x: width, y: -tip * 0.42), control: CGPoint(x: width * 0.28, y: -tip * 0.73))
    path.addQuadCurve(to: CGPoint(x: width * 0.35, y: tail * 0.45), control: CGPoint(x: width * 0.58, y: -tip * 0.15))
    path.addLine(to: CGPoint(x: 0, y: tail)); path.addLine(to: CGPoint(x: -width * 0.35, y: tail * 0.45))
    path.addQuadCurve(to: CGPoint(x: -width, y: -tip * 0.42), control: CGPoint(x: -width * 0.58, y: -tip * 0.15))
    path.addQuadCurve(to: CGPoint(x: 0, y: -tip), control: CGPoint(x: -width * 0.28, y: -tip * 0.73))
    path.closeSubpath()
    return path.offsetBy(dx: rect.midX, dy: rect.midY)
  }
}

struct LiveSecondHand: Shape {
  func path(in rect: CGRect) -> Path {
    let r: CGFloat = 165.44
    var path = Path(); path.move(to: CGPoint(x: rect.midX, y: rect.midY + r * 0.18))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - r * 0.955))
    path.addEllipse(in: CGRect(x: rect.midX - r * 0.033, y: rect.midY + r * 0.097,
      width: r * 0.066, height: r * 0.066))
    return path
  }
}
