package com.xiongjian.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import kotlin.math.min

/** 所有 Provider 和帧提交共用一处布局；完整替换 RemoteViews，避免部分更新累积位图缓存。 */
object WidgetRenderer {
    fun ids(context: Context, mechanical: Boolean): IntArray = AppWidgetManager.getInstance(context).getAppWidgetIds(
        ComponentName(context, if (mechanical) MechanicalWidgetProvider::class.java else ManilaWidgetProvider::class.java))

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (id in ids(context, true)) manager.updateAppWidget(id, mechanical(context, id))
        for (id in ids(context, false)) manager.updateAppWidget(id, manila(context, id))
    }

    fun mechanical(context: Context, id: Int): RemoteViews {
        val view = RemoteViews(context.packageName, R.layout.widget_mechanical)
        val now = System.currentTimeMillis()
        view.setImageViewBitmap(R.id.clock_face, ClockArtwork.mechanical(context, ClockStore.settings(context), now))
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(id)
        val side = (min(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250), options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 250)) - 16).coerceIn(84, 360).toFloat()
        if (Build.VERSION.SDK_INT >= 31) {
            size(view, R.id.clock_stage, side, side)
            size(view, R.id.mechanism_container, side * .2251822f, side * .2251822f)
            margin(view, R.id.mechanism_container, side * .3874089f, side * .5942089f)
        } else {
            view.setViewVisibility(R.id.balance_flipper, View.GONE)
            view.setViewVisibility(R.id.legacy_mechanism, View.VISIBLE)
        }
        view.setOnClickPendingIntent(R.id.clock_stage, openApp(context))
        return view
    }

    /** 动画覆盖层不替代系统 TextClock。动画结束和服务停止时都提交清空覆盖层的完整视图。 */
    fun manila(context: Context, id: Int, overlay: Bitmap? = null, backdrop: Bitmap? = null): RemoteViews {
        val view = RemoteViews(context.packageName, R.layout.widget_manila)
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(id)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300).coerceIn(160, 720).toFloat()
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 220).coerceIn(120, 500).toFloat()
        val scale = min((width - 16) / 360, (height - 16) / 250).coerceAtMost(1.6f)
        if (Build.VERSION.SDK_INT >= 31) {
            size(view, R.id.manila_stage, 360 * scale, 250 * scale)
            for ((target, left) in listOf(R.id.clock_hour_text to 20f, R.id.clock_minute_text to 198f)) {
                size(view, target, 142 * scale, 164 * scale); margin(view, target, left * scale, 0f)
                view.setTextViewTextSize(target, TypedValue.COMPLEX_UNIT_DIP, 139 * scale)
            }
        }
        view.setImageViewBitmap(R.id.manila_background, backdrop ?: ClockArtwork.manila(context, System.currentTimeMillis()))
        view.setViewVisibility(R.id.flip_overlay, if (overlay == null) View.GONE else View.VISIBLE)
        if (overlay != null) view.setImageViewBitmap(R.id.flip_overlay, overlay)
        view.setOnClickPendingIntent(R.id.manila_stage, openApp(context))
        return view
    }

    fun submitFlip(context: Context, overlay: Bitmap, backdrop: Bitmap) {
        val manager = AppWidgetManager.getInstance(context)
        for (id in ids(context, false)) manager.updateAppWidget(id, manila(context, id, overlay, backdrop))
    }

    fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(context, 0,
        Intent(context, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    private fun size(view: RemoteViews, id: Int, width: Float, height: Float) {
        if (Build.VERSION.SDK_INT >= 31) {
            view.setViewLayoutWidth(id, width, TypedValue.COMPLEX_UNIT_DIP)
            view.setViewLayoutHeight(id, height, TypedValue.COMPLEX_UNIT_DIP)
        }
    }
    private fun margin(view: RemoteViews, id: Int, left: Float, top: Float) {
        if (Build.VERSION.SDK_INT >= 31) {
            view.setViewLayoutMargin(id, RemoteViews.MARGIN_LEFT, left, TypedValue.COMPLEX_UNIT_DIP)
            view.setViewLayoutMargin(id, RemoteViews.MARGIN_TOP, top, TypedValue.COMPLEX_UNIT_DIP)
        }
    }
}
