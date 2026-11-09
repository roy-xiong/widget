package com.xiongjian.widget

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/** 仅 Debug 验证包包含此入口；Release 不暴露调试指令或设置写入接口。 */
class WidgetProbeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent?.getStringExtra("command")) {
            "preview" -> startForegroundService(Intent(this, ClockAnimationService::class.java).setAction(ClockAnimationService.PREVIEW))
            "stop" -> { ClockStore.setAnimations(this, false); stopService(Intent(this, ClockAnimationService::class.java)) }
            "settings" -> {
                val raw = intent?.getStringExtra("settings")
                val app = applicationContext
                ClockTasks.execute {
                    val resource = if (ClockSettings.parse(raw).romanScale > 1.1) R.raw.qa_large_dial else R.raw.qa_default_dial
                    val png = app.resources.openRawResource(resource).use { it.readBytes() }
                    ClockStore.publish(app, raw, png)
                    WidgetRenderer.updateAll(app)
                }
            }
        }
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 200)
    }
}
