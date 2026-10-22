import Foundation
import CoreGraphics

let screen = CGRect(x: 0, y: 40, width: 1440, height: 820)
func check(_ frame: CGRect, _ expected: CGPoint, snap: Bool = true, on screen: CGRect = screen) {
  let result = WindowGeometry.constrained(frame, to: screen, snap: snap)
  precondition(result.origin == expected, "unexpected origin: \(result.origin), expected \(expected)")
}
check(CGRect(x: 10, y: 200, width: 360, height: 410), CGPoint(x: 0, y: 200))
check(CGRect(x: 1070, y: 200, width: 360, height: 410), CGPoint(x: 1080, y: 200))
check(CGRect(x: 200, y: 48, width: 360, height: 410), CGPoint(x: 200, y: 40))
check(CGRect(x: 200, y: 440, width: 360, height: 410), CGPoint(x: 200, y: 450))
check(CGRect(x: 10, y: 48, width: 360, height: 410), CGPoint(x: 0, y: 40))
check(CGRect(x: 10, y: 48, width: 360, height: 410), CGPoint(x: 10, y: 48), snap: false)
let leftScreen = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
check(CGRect(x: -1910, y: 0, width: 380, height: 355), CGPoint(x: -1920, y: 0), on: leftScreen)
check(CGRect(x: -1800, y: 100, width: 360, height: 410), CGPoint(x: 0, y: 100), snap: false)
let oversized = WindowGeometry.constrained(CGRect(x: -100, y: -100, width: 2000, height: 2000), to: screen, snap: true)
precondition(oversized == screen)
precondition(WindowGeometry.intersectionArea(screen, leftScreen) == 0)
for index in 0..<1000 {
  let frame = CGRect(x: CGFloat((index * 53) % 6000 - 3000), y: CGFloat((index * 37) % 4000 - 2000), width: 360, height: 410)
  let result = WindowGeometry.constrained(frame, to: leftScreen, snap: index % 2 == 0)
  precondition(leftScreen.contains(result))
}
let tiny = CGRect(x: 8, y: 48, width: 72, height: 82)
let snappedTiny = WindowGeometry.constrained(tiny, to: screen, snap: true)
precondition(snappedTiny.origin == CGPoint(x: 0, y: 40))
precondition(snappedTiny.size == tiny.size)
print("Window geometry: 1012 checks passed")
