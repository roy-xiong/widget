package com.xiongjian.clockhost

import android.app.Activity
import android.appwidget.*
import android.content.ComponentName
import android.os.Bundle
import android.graphics.Color
import android.widget.LinearLayout
import android.widget.TextView

/** 独立 APK/进程承载正式 Provider，与 Launcher 相同地接收系统 RemoteViews。 */
class HostActivity : Activity() {
    lateinit var host: AppWidgetHost
    val views = mutableMapOf<Boolean, AppWidgetHostView>()
    private val allocated = mutableListOf<Int>()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = android.view.Gravity.CENTER_HORIZONTAL; setBackgroundColor(Color.rgb(24, 42, 55)) }
        setContentView(root)
        root.addView(TextView(this).apply { text = "真实 AppWidgetHost · 独立进程"; setTextColor(Color.WHITE); textSize = 14f })
        host = AppWidgetHost(this, 22110); host.startListening()
        val manager = AppWidgetManager.getInstance(this)
        for ((mechanical, name) in listOf(true to "MechanicalWidgetProvider", false to "ManilaWidgetProvider")) {
            val provider = ComponentName("com.xiongjian.widget", "com.xiongjian.widget.$name")
            val info = manager.installedProviders.firstOrNull { it.provider == provider } ?: error("Missing installed provider $provider")
            val id = host.allocateAppWidgetId(); allocated.add(id)
            check(manager.bindAppWidgetIdIfAllowed(id, provider)) { "Run adb shell appwidget grantbind --package com.xiongjian.clockhost --user 0" }
            val height = if (mechanical) 250 else 210
            manager.updateAppWidgetOptions(id, Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 300)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, height)
            })
            val view = host.createView(this, id, info)
            views[mechanical] = view
            root.addView(view, LinearLayout.LayoutParams((300 * resources.displayMetrics.density).toInt(), (height * resources.displayMetrics.density).toInt()))
        }
    }
    override fun onDestroy() {
        if (::host.isInitialized) { allocated.forEach { host.deleteAppWidgetId(it) }; host.stopListening() }
        super.onDestroy()
    }
}
