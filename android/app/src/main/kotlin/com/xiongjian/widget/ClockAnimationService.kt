package com.xiongjian.widget

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.os.*
import java.util.concurrent.atomic.AtomicInteger

/** 仅保留轻量的整分钟计时；翻页 640ms 内提交约 16 帧，其他时间不轮询或发送小组件位图。 */
class ClockAnimationService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private val generation = AtomicInteger()
    private var registered = false
    private val minuteTick = object : Runnable {
        override fun run() {
            if (interactive()) {
                val now = System.currentTimeMillis()
                animate(ClockTime.labels(now - 60_000), ClockTime.labels(now))
            }
            schedule()
        }
    }
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            generation.incrementAndGet()
            main.removeCallbacks(minuteTick)
            ClockTasks.execute { WidgetRenderer.updateAll(applicationContext) }
            if (interactive()) schedule()
        }
    }
    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF); addAction(Intent.ACTION_SCREEN_ON); addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_TIME_CHANGED); addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED) else registerReceiver(receiver, filter)
        registered = true
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP || !ClockStore.animations(this) && intent == null) {
            ClockStore.setAnimations(this, false); stopSelf(); return START_NOT_STICKY
        }
        ClockStore.setAnimations(this, true)
        notification()
        schedule()
        if (intent?.action == PREVIEW && interactive()) {
            val now = System.currentTimeMillis()
            // 预览只演示上一分钟到当前分钟，不改变系统时钟或稳定 TextClock 的当前值。
            main.postDelayed({ if (interactive()) animate(ClockTime.labels(now - 60_000), ClockTime.labels(now)) }, 1800)
        }
        return START_STICKY
    }
    private fun interactive(): Boolean = getSystemService(PowerManager::class.java)?.isInteractive == true && getSystemService(KeyguardManager::class.java)?.isKeyguardLocked != true
    private fun schedule() {
        main.removeCallbacks(minuteTick)
        if (interactive()) main.postDelayed(minuteTick, ClockTime.untilNextMinute(System.currentTimeMillis()) + 15)
    }
    private fun animate(old: Pair<String, String>, next: Pair<String, String>) {
        val token = generation.incrementAndGet()
        val app = applicationContext
        ClockTasks.execute {
            if (WidgetRenderer.ids(app, false).isEmpty()) return@execute
            val backdrop = ClockArtwork.manila(app, System.currentTimeMillis())
            val start = SystemClock.uptimeMillis()
            var frame = 0
            try {
                while (generation.get() == token && interactive()) {
                    val elapsed = SystemClock.uptimeMillis() - start
                    if (elapsed >= ClockTime.FLIP_MS) break
                    val bitmap = FlipFrameRenderer.render(old, next, elapsed / ClockTime.FLIP_MS.toFloat())
                    WidgetRenderer.submitFlip(app, bitmap, backdrop)
                    // 完整 RemoteViews 同步发送完成后即可回收本次覆盖层；宿主已有独立像素副本。
                    bitmap.recycle()
                    frame++
                    val wait = start + frame * 40L - SystemClock.uptimeMillis()
                    if (wait > 0) Thread.sleep(wait)
                }
            } finally {
                WidgetRenderer.updateAll(app)
                backdrop.recycle()
            }
        }
    }
    private fun notification() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "动态桌面时钟", NotificationManager.IMPORTANCE_LOW))
        val stop = PendingIntent.getService(this, 8, Intent(this, ClockAnimationService::class.java).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.ic_clock_notification).setContentTitle("动态桌面时钟已开启")
            .setContentText("整分钟翻页 · 熄屏暂停").setContentIntent(WidgetRenderer.openApp(this)).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "停止动态模式", stop).build()).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(221, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) else startForeground(221, notification)
    }
    override fun onDestroy() {
        generation.incrementAndGet(); main.removeCallbacksAndMessages(null)
        if (registered) { unregisterReceiver(receiver); registered = false }
        ClockTasks.execute { WidgetRenderer.updateAll(applicationContext) }
        super.onDestroy()
    }
    companion object {
        const val START = "com.xiongjian.widget.START"
        const val STOP = "com.xiongjian.widget.STOP"
        const val PREVIEW = "com.xiongjian.widget.PREVIEW"
        private const val CHANNEL = "clock-animation"
    }
}
