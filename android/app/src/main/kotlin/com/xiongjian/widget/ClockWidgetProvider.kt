package com.xiongjian.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/** Receiver 用 goAsync 将绘图交给串行队列，所有路径释放 PendingResult，不在主线程绘制位图。 */
abstract class ClockWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        super.onReceive(context, intent)
        if (intent.action in setOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) refresh(context)
    }
    override fun onUpdate(context: Context?, manager: AppWidgetManager?, ids: IntArray?) { context?.let { refresh(it) } }
    override fun onAppWidgetOptionsChanged(context: Context?, manager: AppWidgetManager?, id: Int, options: Bundle?) { context?.let { refresh(it) } }
    override fun onEnabled(context: Context?) { context?.let { ClockWeatherJob.schedule(it) } }
    override fun onDisabled(context: Context?) {
        if (context == null) return
        if (WidgetRenderer.ids(context, true).isEmpty() && WidgetRenderer.ids(context, false).isEmpty()) {
            ClockWeatherJob.cancel(context)
            context.stopService(Intent(context, ClockAnimationService::class.java))
        }
    }
    private fun refresh(context: Context) {
        val pending = goAsync()
        val app = context.applicationContext
        ClockTasks.execute {
            try { WidgetRenderer.updateAll(app); ClockWeatherJob.schedule(app) } finally { pending?.finish() }
        }
    }
}
class MechanicalWidgetProvider : ClockWidgetProvider()
class ManilaWidgetProvider : ClockWidgetProvider()
