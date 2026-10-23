# 桌面时钟

基于 Flutter **3.44.4 / Dart 3.12.2** 的 macOS 悬浮时钟与 iOS 时钟 App。

## 功能

- 机械月相：在 dianbo 原表盘上接入已确认的小月相与开放式陀飞轮，保留罗马刻度、蓝钢指针、星期日历和每秒 8 次步进。
- Manila：参考早期 HTC TouchFLO / Sense 瘦长双翻页牌与半透明玻璃底座；城市在左、天气图案居中、日期温度在右。macOS 使用原生玻璃采样桌面背景。只显示小时、分钟，时间变化时三维翻页。
- macOS：透明无边框窗口、置顶开关、拖动、18pt 边缘吸附、多显示器和位置恢复、20%～160% 大小调节、菜单栏入口。
- 天气：手动选择/搜索城市，约每 15 分钟刷新；离线保留上次数据并显示更新状态。初始城市为北京，可在设置中更改。
- 机械表三项尺寸独立调整：月相、星期日历、罗马数字各 50%～150%，自动保存。
- iOS 18+：提供机械月相、马尼拉天气两种原生 WidgetKit 小组件，支持小号和中号，可同时添加。iOS 27 可用。
- 马尼拉小组件的时、分使用系统 `TimeDataSource` 自动更新。机械表的指针按五分钟时间线由系统调度刷新，并附实时数字时间；小组件不持续运行秒针、陀飞轮或三维翻页动画。
- App 的三个尺寸和天气城市通过 App Group 同步到小组件；App 被结束后，扩展仍可独立请求天气。

鼠标进入时钟后显示工具栏。点击切换图标选择另一种外观，图钉控制置顶，设置按钮选择大小和城市。缩小后工具栏显示紧凑设置入口，也可双击时钟或从 macOS 菜单栏时钟图标进入设置。

## 构建与产物

与 BBK 相同的 GitHub Actions 模式：主分支推送自动验证并打包，`Desktop Clock beta` 可手动选择 `all / macos / ios`。

流水线执行格式检查、静态分析、Flutter 回归，以及独立 Swift 窗口几何边界验证，然后构建：

- `DesktopClock-macOS-universal.dmg` / `.zip`：Intel + Apple Silicon，ad-hoc 签名测试包，未公证。
- `DesktopClock-iOS-unsigned.ipa`：设备 Release 未签名包，内含 `PlugIns/ClockWidgets.appex`，需要同时签名 App 与扩展。

签名时，App 标识为 `com.xiongjian.widget`，扩展为 `com.xiongjian.widget.ClockWidgets`；两者须由同一开发者团队签名，并启用相同 App Group `group.com.xiongjian.widget`。如果重签工具改了 bundle ID，也应一起修改两个 entitlement 和共享组代码后重新构建。缺少共享组时，小组件只能使用默认设置，App 设置页会提示同步失败。

安装后先打开 App 一次，再长按 iPhone 主屏幕 → 编辑 → 添加小组件 → 搜索“桌面时钟”。旧版升级后可继续使用原城市与窗口偏好。
- 每种产物附 SHA-256；Actions 保留 14 天，同时发布独立的 GitHub Preview Release。

Apple 两端不使用 NDK。`toolchain.json` 记录 BBK Android 基线：NDK 27.2.12479018、AGP 9.0.1、Kotlin 2.3.20、Gradle 9.1.0、Java 17、minSdk 24，以备后续新增 Android 工程。

仓库不包含证书、签名密钥或个人账号数据。本地按用户要求不自动执行平台编译。

## 结构

- `lib/ui/clock_dial.dart`：基于 dianbo 并接入已确认的小月相、陀飞轮与居中日历。
- `lib/ui/flip_tile.dart`：上下半牌面的三维翻页与减少动态效果适配。
- `lib/ui/clock_controller.dart`：时钟、生命周期、偏好写入序列、天气请求代次。
- `lib/data/`：原生偏好存储、Open-Meteo 请求与校验。
- `macos/Runner/MainFlutterWindow.swift`：主线程窗口状态、菜单栏、拖动与通道。
- `macos/Runner/WindowGeometry.swift`：独立且可验证的多屏夹取和吸边算法。
- `test/render_previews_test.dart`：直接从正式表盘导出 PNG，`Render clock previews` 流水线负责执行。

天气时间与时区：表盘显示**本机系统时间和系统时区**；所选城市只影响天气，不会改变时钟时区。天气信息来自模型估计，数据源为 [Open-Meteo](https://open-meteo.com/)（免费非商业服务，按要求保留归属）。

设计参考：[HTC Aria 用户手册第 117 页](https://www.att.com/support_static_files/manuals/HTC_Aria.pdf#page=117)。天气图形由代码自行绘制，没有使用 HTC 的原始位图或字体文件。

## 小组件实现与验证

- `ios/ClockWidgets/`：SwiftUI 扩展、系统动态数字时间、独立天气客户端和时间线。
- `ios/Shared/ClockWidgetData.swift`：校验与解析 Flutter JSON、App Group 存储及时间线计划。
- `lib/platform/widget_sync_service.dart`：合并滑杆变化，用现有 Flutter 画笔导出底图，显式释放图片和 paragraph 资源。
- CI 在 iOS 打包前执行模型/网络回归，并生成默认表盘资源。出包脚本校验 `.appex`、arm64 架构和主包/扩展版本一致性。
- 本地只做格式和静态检查，平台编译、测试、资源渲染均由 GitHub Actions 执行。
