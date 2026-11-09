package com.xiongjian.widget

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter 只负责设置与预览；桌面宿主不加载 Flutter，也不保留 Activity 引用。 */
class MainActivity : FlutterActivity() {
    private var preferencesChannel: MethodChannel? = null
    private var widgetsChannel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val app = applicationContext
        preferencesChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.xiongjian.widget/preferences").also { channel ->
            channel.setMethodCallHandler { call, result ->
                val key = if (call.method == "read") call.arguments as? String else call.argument<String>("key")
                if (key !in setOf("settings", "weather")) {
                    result.error("BAD_ARGUMENT", "无效设置键", null)
                } else if (call.method == "read") {
                    result.success(ClockStore.read(app, key ?: ""))
                } else if (call.method == "write") {
                    val raw = call.argument<String>("value")
                    ClockTasks.execute {
                        try {
                            ClockStore.write(app, key ?: "", raw)
                            if (key == "weather") WidgetRenderer.updateAll(app)
                            main.post { result.success(null) }
                        } catch (_: Exception) { main.post { result.error("WRITE", "设置保存失败", null) } }
                    }
                } else result.notImplemented()
            }
        }
        widgetsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.xiongjian.widget/widgets").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "publishSettings" -> {
                        val raw = call.argument<String>("settings")
                        val png = call.argument<ByteArray>("png")
                        ClockTasks.execute {
                            try {
                                ClockStore.publish(app, raw, png)
                                WidgetRenderer.updateAll(app)
                                main.post { result.success(null) }
                            } catch (_: Exception) { main.post { result.error("WIDGET_WRITE", "小组件设置写入失败", null) } }
                        }
                    }
                    "startAnimations", "previewFlip" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 44)
                            }
                            val intent = Intent(app, ClockAnimationService::class.java).setAction(if (call.method == "previewFlip") ClockAnimationService.PREVIEW else ClockAnimationService.START)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(null)
                        } catch (_: Exception) { result.error("SERVICE", "请在 App 前台启动动态模式", null) }
                    }
                    "stopAnimations" -> {
                        ClockStore.setAnimations(app, false)
                        stopService(Intent(app, ClockAnimationService::class.java))
                        ClockTasks.execute { WidgetRenderer.updateAll(app) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        preferencesChannel?.setMethodCallHandler(null)
        widgetsChannel?.setMethodCallHandler(null)
        preferencesChannel = null
        widgetsChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
