import SwiftUI
import UIKit

/** 框体、刻度使用 Flutter 原画笔底图；月相日历由时间线绘制，活动机械层单独由系统驱动。 */
struct NativeMechanicalFace: View {
  let entry: ClockEntry
  private var background: UIImage? {
    if let path = ClockWidgetStore.dialURL(scale: entry.settings.romanScale, moving: ClockMotionRuntime.available)?.path,
       let image = UIImage(contentsOfFile: path) { return image }
    if abs(entry.settings.romanScale - 1) < 0.001 { return UIImage(named: ClockMotionRuntime.available ? "MotionDial" : "DefaultDial") }
    return nil
  }
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let image = background { Image(uiImage: image).resizable().scaledToFit() }
        else { FallbackDial(romanScale: entry.settings.romanScale) }
        Canvas { context, size in
          let side = min(size.width, size.height)
          context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
          context.scaleBy(x: side / 360, y: side / 360)
          drawMoon(&context)
          drawCalendar(&context)
          if !ClockMotionRuntime.available { drawHands(&context) }
        }
        if ClockMotionRuntime.available {
          LiveMechanicalMotion().frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
        }
      }.frame(width: geometry.size.width, height: geometry.size.height)
    }
  }

  private let r: CGFloat = 165.44
  private func drawCalendar(_ context: inout GraphicsContext) {
    var context = context
    context.translateBy(x: 180 + r * 0.4, y: 180)
    context.scaleBy(x: entry.settings.calendarScale, y: entry.settings.calendarScale)
    let rect = CGRect(x: -r * 0.27, y: -r * 0.1175, width: r * 0.54, height: r * 0.235)
    let path = Path(roundedRect: rect, cornerRadius: r * 0.035)
    context.fill(path, with: .linearGradient(Gradient(colors: [Color(red: 0.84, green: 0.82, blue: 0.77), Color(white: 0.99)]),
      startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
    context.stroke(path, with: .color(Color(white: 0.65)), lineWidth: r * 0.016)
    var divider = Path(); divider.move(to: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.15))
    divider.addLine(to: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.maxY - rect.height * 0.15))
    context.stroke(divider, with: .color(Color(white: 0.66)), lineWidth: r * 0.008)
    let weekday = Calendar.current.component(.weekday, from: entry.date)
    let day = Calendar.current.component(.day, from: entry.date)
    let font = Font.custom("PingFangSC-Semibold", size: r * 0.135)
    context.draw(Text("周\(["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, weekday - 1))])")
      .font(font).foregroundColor(Color(white: 0.16)), at: CGPoint(x: rect.minX + rect.width * 0.305, y: 0))
    context.draw(Text(String(format: "%02d", day)).font(font).foregroundColor(Color(white: 0.16)),
      at: CGPoint(x: rect.minX + rect.width * 0.805, y: 0))
  }

  private func drawMoon(_ context: inout GraphicsContext) {
    var context = context
    context.translateBy(x: 180, y: 180 - r * 0.52)
    context.scaleBy(x: 0.56 * entry.settings.moonScale, y: 0.56 * entry.settings.moonScale)
    context.translateBy(x: 0, y: -r * 0.375)
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * r, y: (y - 0.045) * r) }
    var path = Path(); path.move(to: point(-0.46, 0.61))
    path.addCurve(to: point(0, 0.23), control1: point(-0.46, 0.40), control2: point(-0.25, 0.23))
    path.addCurve(to: point(0.46, 0.61), control1: point(0.25, 0.23), control2: point(0.46, 0.40))
    path.addCurve(to: point(0.23, 0.49), control1: point(0.34, 0.61), control2: point(0.34, 0.47))
    path.addCurve(to: point(0, 0.61), control1: point(0.12, 0.50), control2: point(0.12, 0.61))
    path.addCurve(to: point(-0.23, 0.49), control1: point(-0.12, 0.61), control2: point(-0.12, 0.50))
    path.addCurve(to: point(-0.46, 0.61), control1: point(-0.34, 0.47), control2: point(-0.34, 0.61)); path.closeSubpath()
    context.fill(path, with: .linearGradient(Gradient(colors: [Color(red: 0.04, green: 0.08, blue: 0.21), Color(red: 0.12, green: 0.24, blue: 0.44)]),
      startPoint: point(0, 0.23), endPoint: point(0, 0.61)))
    var clipped = context; clipped.clip(to: path)
    let reference = Date(timeIntervalSince1970: 1712600460)
    let cycles = entry.date.timeIntervalSince(reference) / (86400 * 29.530589)
    clipped.translateBy(x: 0, y: r * 0.705); clipped.rotate(by: .radians(.pi * (cycles - floor(cycles))))
    for direction in [CGFloat(-1), CGFloat(1)] {
      let moon = CGRect(x: direction * r * 0.34 - r * 0.155, y: -r * 0.155, width: r * 0.31, height: r * 0.31)
      clipped.fill(Path(ellipseIn: moon), with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.92, blue: 0.69), Color(red: 0.72, green: 0.54, blue: 0.25)]),
        center: CGPoint(x: moon.midX - r * 0.05, y: -r * 0.05), startRadius: 0, endRadius: r * 0.25))
    }
    for star in [CGPoint(x: -0.45, y: -0.24), CGPoint(x: 0, y: -0.52), CGPoint(x: 0.45, y: -0.24), CGPoint(x: 0.1, y: 0.47)] {
      clipped.draw(Text("✦").font(.system(size: r * 0.06)).foregroundColor(.yellow), at: CGPoint(x: star.x * r, y: star.y * r))
    }
    context.stroke(path, with: .color(Color(white: 0.65)), lineWidth: r * 0.012)
  }

  private func drawHands(_ context: inout GraphicsContext) {
    let calendar = Calendar.current
    let minute = CGFloat(calendar.component(.minute, from: entry.date))
    let hour = CGFloat(calendar.component(.hour, from: entry.date) % 12)
    drawHand(&context, turns: (hour + minute / 60) / 12, length: 0.70, halfWidth: 0.044)
    drawHand(&context, turns: minute / 60, length: 0.94, halfWidth: 0.028)
    let pin = CGRect(x: 180 - r * 0.058, y: 180 - r * 0.058, width: r * 0.116, height: r * 0.116)
    context.fill(Path(ellipseIn: pin), with: .radialGradient(Gradient(colors: [.white, Color(red: 0.27, green: 0.35, blue: 0.42)]),
      center: CGPoint(x: 177, y: 177), startRadius: 0, endRadius: r * 0.09))
    context.fill(Path(ellipseIn: pin.insetBy(dx: r * 0.033, dy: r * 0.033)), with: .color(Color(red: 0.04, green: 0.16, blue: 0.3)))
  }
  private func drawHand(_ context: inout GraphicsContext, turns: CGFloat, length: CGFloat, halfWidth: CGFloat) {
    var context = context; context.translateBy(x: 180, y: 180); context.rotate(by: .radians(Double(turns) * .pi * 2))
    let tip = r * length, width = r * halfWidth, tail = r * 0.09
    var path = Path(); path.move(to: CGPoint(x: 0, y: -tip))
    path.addQuadCurve(to: CGPoint(x: width, y: -tip * 0.42), control: CGPoint(x: width * 0.28, y: -tip * 0.73))
    path.addQuadCurve(to: CGPoint(x: width * 0.35, y: tail * 0.45), control: CGPoint(x: width * 0.58, y: -tip * 0.15))
    path.addLine(to: CGPoint(x: 0, y: tail)); path.addLine(to: CGPoint(x: -width * 0.35, y: tail * 0.45))
    path.addQuadCurve(to: CGPoint(x: -width, y: -tip * 0.42), control: CGPoint(x: -width * 0.58, y: -tip * 0.15))
    path.addQuadCurve(to: CGPoint(x: 0, y: -tip), control: CGPoint(x: -width * 0.28, y: -tip * 0.73)); path.closeSubpath()
    context.fill(path, with: .linearGradient(Gradient(colors: [Color(red: 0.03, green: 0.09, blue: 0.18),
      Color(red: 0.54, green: 0.71, blue: 0.82), Color(red: 0.02, green: 0.07, blue: 0.15)]),
      startPoint: CGPoint(x: -width, y: 0), endPoint: CGPoint(x: width, y: 0)))
  }
}

/** 首次打开 App 前或共享底图缺失时的可用降级，尺寸参数仍然生效。 */
struct FallbackDial: View {
  let romanScale: Double
  private let numerals = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) * 0.46
      context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(white: 0.98)))
      context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)), with: .color(.gray), lineWidth: r * 0.04)
      for index in 0..<60 {
        let angle = Double(index) * .pi / 30 - .pi / 2
        var path = Path(); path.move(to: CGPoint(x: center.x + cos(angle) * r * 0.91, y: center.y + sin(angle) * r * 0.91))
        path.addLine(to: CGPoint(x: center.x + cos(angle) * r * 0.96, y: center.y + sin(angle) * r * 0.96))
        context.stroke(path, with: .color(.gray), lineWidth: index % 5 == 0 ? 1.5 : 0.6)
      }
      for index in 0..<12 {
        let angle = Double(index) * .pi / 6 - .pi / 2
        context.draw(Text(numerals[index]).font(.system(size: r * 0.15 * romanScale, weight: .semibold, design: .serif)).foregroundColor(Color(white: 0.12)),
          at: CGPoint(x: center.x + cos(angle) * r * 0.80, y: center.y + sin(angle) * r * 0.80))
      }
      let aperture = CGRect(x: center.x - r * 0.245, y: center.y + r * 0.205, width: r * 0.49, height: r * 0.49)
      context.fill(Path(ellipseIn: aperture), with: .color(Color(white: 0.09)))
      context.draw(Text("⚙").font(.system(size: r * 0.43)).foregroundColor(Color(red: 0.79, green: 0.65, blue: 0.39)), at: CGPoint(x: aperture.midX, y: aperture.midY))
    }
  }
}
