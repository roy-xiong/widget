import Cocoa
import FlutterMacOS

/**
 * 透明桌面时钟窗口。AppKit 状态仅在主线程修改，通道与通知使用弱引用或显式移除。
 * 置顶使用 floating 层级；关闭置顶后回到普通窗口层级，不抢占键盘焦点。
 */
class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?
  private var preferencesChannel: FlutterMethodChannel?
  private var statusItem: NSStatusItem?
  private var pinItem: NSMenuItem?
  private var settings: [String: Any] = [:]
  private var editingSettings = false
  private var dragMouse: NSPoint?
  private var dragOrigin: NSPoint?
  private var snapping = true

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func awakeFromNib() {
    super.awakeFromNib()
    styleMask = [.borderless]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    title = "桌面时钟"
    let controller = FlutterViewController()
    controller.backgroundColor = .clear
    contentViewController = controller
    RegisterGeneratedPlugins(registry: controller)

    let messenger = controller.engine.binaryMessenger
    let channel = FlutterMethodChannel(name: "com.xiongjian.widget/window", binaryMessenger: messenger)
    windowChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        guard let owner = self else { result(FlutterError(code: "CLOSED", message: "窗口已关闭", details: nil)); return }
        owner.handle(call, result: result)
      }
    }
    let preferences = FlutterMethodChannel(name: "com.xiongjian.widget/preferences", binaryMessenger: messenger)
    preferencesChannel = preferences
    preferences.setMethodCallHandler { call, result in
      DispatchQueue.main.async { Self.handlePreferences(call, result: result) }
    }
    if let raw = UserDefaults.standard.string(forKey: "widget.settings"),
       let data = raw.data(using: .utf8),
       let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { settings = saved }
    installMenu()
    applyConfiguration()
    if let x = UserDefaults.standard.object(forKey: "widget.origin.x") as? NSNumber,
       let y = UserDefaults.standard.object(forKey: "widget.origin.y") as? NSNumber,
       x.doubleValue.isFinite, y.doubleValue.isFinite {
      setFrameOrigin(NSPoint(x: x.doubleValue, y: y.doubleValue))
    } else { center() }
    constrainToScreen(snap: false)
    NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenChanged), name: NSWorkspace.didWakeNotification, object: nil)
  }

  /** 白名单键及长度校验阻止异常参数写入任意偏好，损坏 JSON 留给 Dart 回退。 */
  private static func handlePreferences(_ call: FlutterMethodCall, result: FlutterResult) {
    let keys = ["settings", "weather"]
    if call.method == "read", let key = call.arguments as? String, keys.contains(key) {
      result(UserDefaults.standard.string(forKey: "widget.\(key)"))
    } else if call.method == "write", let args = call.arguments as? [String: Any],
              let key = args["key"] as? String, keys.contains(key),
              let value = args["value"] as? String, value.utf8.count <= 131072 {
      UserDefaults.standard.set(value, forKey: "widget.\(key)"); result(nil)
    } else { result(FlutterError(code: "BAD_ARGUMENT", message: "无效设置参数", details: nil)) }
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "configure":
      guard let value = call.arguments as? [String: Any] else { result(FlutterError(code: "BAD_ARGUMENT", message: "无效窗口设置", details: nil)); return }
      settings = value; applyConfiguration(); result(nil)
    case "settingsVisible":
      editingSettings = call.arguments as? Bool ?? false
      applyConfiguration(); result(nil)
    case "drag":
      let phase = call.arguments as? String
      if phase == "begin" { dragMouse = NSEvent.mouseLocation; dragOrigin = frame.origin }
      else if phase == "update", let mouse = dragMouse, let origin = dragOrigin {
        let current = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(x: origin.x + current.x - mouse.x, y: origin.y + current.y - mouse.y))
      } else if phase == "end" { dragMouse = nil; dragOrigin = nil; constrainToScreen(snap: snapping); saveOrigin() }
      result(nil)
    case "quit": result(nil); NSApp.terminate(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  /** 设置页有独立大小；回到时钟时按当前外观与比例还原，保留原窗口的上边缘。 */
  private func applyConfiguration() {
    let pinned = settings["alwaysOnTop"] as? Bool ?? true
    snapping = settings["snapToEdge"] as? Bool ?? true
    level = pinned ? .floating : .normal
    pinItem?.state = pinned ? .on : .off
    let rawScale = (settings["scale"] as? NSNumber)?.doubleValue ?? 1
    let scale = rawScale.isFinite ? min(1.6, max(0.7, rawScale)) : 1
    let manila = settings["style"] as? String == "manila"
    let desired = editingSettings ? NSSize(width: 420, height: 620) :
      NSSize(width: (manila ? 380 : 360) * scale, height: (manila ? 355 : 410) * scale)
    let visible = selectedFrame()
    let fit = min(1, visible.width / desired.width, visible.height / desired.height)
    let size = NSSize(width: desired.width * fit, height: desired.height * fit)
    let newFrame = NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    setFrame(newFrame, display: true)
    constrainToScreen(snap: false)
  }

  /** 多显示器按交叠面积选择目标屏幕，支持负坐标；移除屏幕后回到仍可见的屏幕。 */
  private func selectedFrame() -> NSRect {
    let screens = NSScreen.screens
    if let screen = screens.max(by: {
      WindowGeometry.intersectionArea(frame, $0.visibleFrame) < WindowGeometry.intersectionArea(frame, $1.visibleFrame)
    }), WindowGeometry.intersectionArea(frame, screen.visibleFrame) > 0 { return screen.visibleFrame }
    return screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
  }
  private func constrainToScreen(snap: Bool) {
    setFrame(WindowGeometry.constrained(frame, to: selectedFrame(), snap: snap), display: true)
  }
  private func saveOrigin() {
    UserDefaults.standard.set(frame.origin.x, forKey: "widget.origin.x")
    UserDefaults.standard.set(frame.origin.y, forKey: "widget.origin.y")
  }
  @objc private func screenChanged() { constrainToScreen(snap: false); saveOrigin() }

  private func installMenu() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem = item
    if #available(macOS 11.0, *) { item.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "桌面时钟") }
    else { item.button?.title = "◷" }
    let menu = NSMenu()
    func add(_ title: String, _ selector: Selector) -> NSMenuItem {
      let entry = NSMenuItem(title: title, action: selector, keyEquivalent: "")
      entry.target = self; menu.addItem(entry); return entry
    }
    _ = add("显示时钟", #selector(showClock))
    pinItem = add("始终置顶", #selector(togglePin))
    _ = add("时钟设置…", #selector(showSettings))
    menu.addItem(.separator())
    _ = add("退出桌面时钟", #selector(quitClock))
    item.menu = menu
  }
  @objc private func showClock() { makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
  @objc private func togglePin() { windowChannel?.invokeMethod("togglePin", arguments: nil) }
  @objc private func showSettings() { showClock(); windowChannel?.invokeMethod("showSettings", arguments: nil) }
  @objc private func quitClock() { NSApp.terminate(nil) }

  deinit {
    windowChannel?.setMethodCallHandler(nil); preferencesChannel?.setMethodCallHandler(nil)
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
  }
}
