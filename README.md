# 桌面时钟

基于 Flutter **3.44.4 / Dart 3.12.2** 的 macOS 悬浮时钟与 iOS 时钟 App。

## 功能

- 机械月相：逐字节复用 `dianbo/lib/clock_dial.dart`，保留罗马刻度、蓝钢指针、星期日历、月相和每秒 8 次步进。
- Manila：参考早期 HTC TouchFLO / Sense 白色双翻页牌与深色天气底座；只显示小时、分钟，时间变化时三维翻页。
- macOS：透明无边框窗口、置顶开关、拖动、18pt 边缘吸附、多显示器和位置恢复、70%～160% 大小调节、菜单栏入口。
- 天气：手动选择/搜索城市，约每 15 分钟刷新；离线保留上次数据并显示更新状态。初始城市为北京，可在设置中更改。
- iOS：复用两种时钟和天气设置。**持续翻页的桌面小组件暂缓**；本版没有 WidgetKit 扩展，也不提供跨 App 悬浮窗口。

鼠标进入时钟后显示工具栏。点击切换图标选择另一种外观，图钉控制置顶，设置按钮选择大小和城市。也可以从 macOS 菜单栏时钟图标进入设置。

## 构建与产物

与 BBK 相同的 GitHub Actions 模式：主分支推送自动验证并打包，`Desktop Clock beta` 可手动选择 `all / macos / ios`。

流水线执行格式检查、静态分析、Flutter 回归，以及独立 Swift 窗口几何边界验证，然后构建：

- `DesktopClock-macOS-universal.dmg` / `.zip`：Intel + Apple Silicon，ad-hoc 签名测试包，未公证。
- `DesktopClock-iOS-unsigned.ipa`：设备 Release 未签名包，需要自行重签名安装。
- 每种产物附 SHA-256；Actions 保留 14 天，同时发布独立的 GitHub Preview Release。

Apple 两端不使用 NDK。`toolchain.json` 记录 BBK Android 基线：NDK 27.2.12479018、AGP 9.0.1、Kotlin 2.3.20、Gradle 9.1.0、Java 17、minSdk 24，以备后续新增 Android 工程。

仓库不包含证书、签名密钥或个人账号数据。本地按用户要求不自动执行平台编译。

## 结构

- `lib/ui/clock_dial.dart`：来自 dianbo 的原始表盘。
- `lib/ui/flip_tile.dart`：上下半牌面的三维翻页与减少动态效果适配。
- `lib/ui/clock_controller.dart`：时钟、生命周期、偏好写入序列、天气请求代次。
- `lib/data/`：原生偏好存储、Open-Meteo 请求与校验。
- `macos/Runner/MainFlutterWindow.swift`：主线程窗口状态、菜单栏、拖动与通道。
- `macos/Runner/WindowGeometry.swift`：独立且可验证的多屏夹取和吸边算法。

天气时间与时区：表盘显示**本机系统时间和系统时区**；所选城市只影响天气，不会改变时钟时区。天气信息来自模型估计，数据源为 [Open-Meteo](https://open-meteo.com/)（免费非商业服务，按要求保留归属）。

设计参考：[HTC Aria 用户手册第 117 页](https://www.att.com/support_static_files/manuals/HTC_Aria.pdf#page=117)。天气图形由代码自行绘制，没有使用 HTC 的原始位图或字体文件。
