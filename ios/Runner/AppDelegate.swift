import Flutter
import UIKit
import WidgetKit

/** App 偏好保留原存储，另写入共享容器；扩展独立运行，不持有 Flutter 或 App 的 UI。 */
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var preferencesChannel: FlutterMethodChannel?
  private var widgetChannel: FlutterMethodChannel?
  private var reloadWork: DispatchWorkItem?
  private let widgetFiles = DispatchQueue(label: "com.xiongjian.widget.files", qos: .utility)

  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    // 老版本设置无须重填。App 与扩展用不同进程，JSON 按键原子替换。
    for key in ["settings", "weather"] {
      if let value = UserDefaults.standard.string(forKey: "widget.\(key)") {
        ClockWidgetStore.defaults?.set(value, forKey: "widget.\(key)")
      }
    }
    let preferences = FlutterMethodChannel(name: "com.xiongjian.widget/preferences", binaryMessenger: messenger)
    preferencesChannel = preferences
    preferences.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        let keys = ["settings", "weather"]
        if call.method == "read", let key = call.arguments as? String, keys.contains(key) {
          result(UserDefaults.standard.string(forKey: "widget.\(key)"))
        } else if call.method == "write", let args = call.arguments as? [String: Any],
          let key = args["key"] as? String, keys.contains(key),
          let value = args["value"] as? String, value.utf8.count <= 131072 {
          UserDefaults.standard.set(value, forKey: "widget.\(key)")
          ClockWidgetStore.defaults?.set(value, forKey: "widget.\(key)")
          self?.scheduleWidgetReload(); result(nil)
        } else { result(FlutterError(code: "BAD_ARGUMENT", message: "无效设置参数", details: nil)) }
      }
    }
    let widgets = FlutterMethodChannel(name: "com.xiongjian.widget/widgets", binaryMessenger: messenger)
    widgetChannel = widgets
    widgets.setMethodCallHandler { [weak self] call, result in
      guard call.method == "publishDial", let args = call.arguments as? [String: Any],
            let png = args["png"] as? FlutterStandardTypedData,
            let scale = args["romanScale"] as? NSNumber, scale.doubleValue.isFinite,
            png.data.count <= 1048576, png.data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
            let owner = self else {
        result(FlutterError(code: "BAD_ARGUMENT", message: "无效小组件底图", details: nil)); return
      }
      let data = png.data
      owner.widgetFiles.async { [weak owner] in
        guard let url = ClockWidgetStore.dialURL(scale: scale.doubleValue, moving: args["moving"] as? Bool ?? false) else {
          DispatchQueue.main.async { result(FlutterError(code: "APP_GROUP", message: "签名未启用 App Group", details: nil)) }; return
        }
        do {
          try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
          DispatchQueue.main.async { owner?.scheduleWidgetReload(); result(nil) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "WIDGET_WRITE", message: "小组件底图保存失败", details: nil)) }
        }
      }
    }
    scheduleWidgetReload()
  }

  /** 合并连续滑杆变化；不按秒请求 WidgetKit 重载，避免耗尽系统刷新预算。 */
  private func scheduleWidgetReload() {
    reloadWork?.cancel()
    let work = DispatchWorkItem {
      if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
    }
    reloadWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
  }

  deinit {
    reloadWork?.cancel()
    preferencesChannel?.setMethodCallHandler(nil); widgetChannel?.setMethodCallHandler(nil)
  }
}
