import Flutter
import UIKit

/** iOS 仅提供普通时钟 App；动态桌面小组件按用户决定暂缓。 */
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var preferencesChannel: FlutterMethodChannel?
  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "com.xiongjian.widget/preferences", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    preferencesChannel = channel
    channel.setMethodCallHandler { call, result in
      DispatchQueue.main.async {
        let keys = ["settings", "weather"]
        if call.method == "read", let key = call.arguments as? String, keys.contains(key) {
          result(UserDefaults.standard.string(forKey: "widget.\(key)"))
        } else if call.method == "write", let args = call.arguments as? [String: Any],
          let key = args["key"] as? String, keys.contains(key),
          let value = args["value"] as? String, value.utf8.count <= 131072 {
          UserDefaults.standard.set(value, forKey: "widget.\(key)"); result(nil)
        } else { result(FlutterError(code: "BAD_ARGUMENT", message: "无效设置参数", details: nil)) }
      }
    }
  }
}
