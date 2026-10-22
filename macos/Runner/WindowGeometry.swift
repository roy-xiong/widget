import Foundation
import CoreGraphics

/**
 * 无窗口依赖的几何计算，CI 可独立验证四边、角落、多屏负坐标和屏幕移除。
 * 仅在拖动结束时吸附；普通夹取只保证窗口完整留在可用屏幕区域内。
 */
enum WindowGeometry {
  static func intersectionArea(_ frame: CGRect, _ screen: CGRect) -> CGFloat {
    let rect = frame.intersection(screen)
    return rect.isNull ? 0 : rect.width * rect.height
  }
  static func constrained(_ frame: CGRect, to screen: CGRect, snap: Bool, threshold: CGFloat = 18) -> CGRect {
    let width = min(frame.width, screen.width), height = min(frame.height, screen.height)
    var x = min(max(frame.minX, screen.minX), screen.maxX - width)
    var y = min(max(frame.minY, screen.minY), screen.maxY - height)
    if snap {
      if abs(x - screen.minX) <= threshold { x = screen.minX }
      else if abs(x + width - screen.maxX) <= threshold { x = screen.maxX - width }
      if abs(y - screen.minY) <= threshold { y = screen.minY }
      else if abs(y + height - screen.maxY) <= threshold { y = screen.maxY - height }
    }
    return CGRect(x: x, y: y, width: width, height: height)
  }
}
