package com.xiongjian.widget

import android.content.Context
import android.graphics.*
import java.util.Calendar
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** 静态画布使用 360 设计坐标。指针/陀飞轮是正式 Flutter 导出资源，不另画近似图形。 */
object ClockArtwork {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val assets = mutableMapOf<Int, Bitmap>()
    private fun bitmap(context: Context, id: Int): Bitmap = assets.getOrPut(id) { BitmapFactory.decodeResource(context.resources, id) }

    /** 此对象由 ClockTasks 单队列调用；输出不复用可变 Canvas，RemoteViews 不会持有下一帧的像素。 */
    fun mechanical(context: Context, settings: ClockSettings, now: Long): Bitmap {
        resetPaint()
        val result = Bitmap.createBitmap(512, 512, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result).apply { scale(512 / 360f, 512 / 360f) }
        val file = ClockStore.dial(context, settings)
        val custom = if (file.isFile && file.length() <= 1048576) BitmapFactory.decodeFile(file.path) else null
        canvas.drawBitmap(custom ?: bitmap(context, R.drawable.clock_dial), null, RectF(0f, 0f, 360f, 360f), paint)
        custom?.recycle()
        moon(canvas, settings.moonScale.toFloat(), ClockTime.moon(now))
        calendar(canvas, settings.calendarScale.toFloat(), now)
        canvas.drawBitmap(bitmap(context, R.drawable.tourbillon_rim), null, RectF(139.4672f, 213.9152f, 220.5328f, 294.9808f), paint)
        return result
    }

    private fun moon(canvas: Canvas, scale: Float, fraction: Double) {
        canvas.save(); canvas.translate(180f, 93.9712f); canvas.scale(.56f * scale, .56f * scale); canvas.translate(0f, -62.04f)
        val r = 165.44f
        fun y(v: Float) = (v - .045f) * r
        val path = Path().apply {
            moveTo(-.46f * r, y(.61f))
            cubicTo(-.46f * r, y(.4f), -.25f * r, y(.23f), 0f, y(.23f))
            cubicTo(.25f * r, y(.23f), .46f * r, y(.4f), .46f * r, y(.61f))
            cubicTo(.34f * r, y(.61f), .34f * r, y(.47f), .23f * r, y(.49f))
            cubicTo(.12f * r, y(.5f), .12f * r, y(.61f), 0f, y(.61f))
            cubicTo(-.12f * r, y(.61f), -.12f * r, y(.5f), -.23f * r, y(.49f))
            cubicTo(-.34f * r, y(.47f), -.34f * r, y(.61f), -.46f * r, y(.61f)); close()
        }
        paint.shader = LinearGradient(0f, y(.23f), 0f, y(.61f), intArrayOf(0xff0a1537.toInt(), 0xff203d70.toInt()), null, Shader.TileMode.CLAMP)
        canvas.drawPath(path, paint); paint.shader = null
        canvas.save(); canvas.clipPath(path); canvas.translate(0f, r * .705f); canvas.rotate((fraction * 180).toFloat())
        for (direction in listOf(-1, 1)) {
            paint.shader = RadialGradient(direction * r * .34f - 8, -8f, r * .22f, intArrayOf(0xffffeab2.toInt(), 0xffb88a40.toInt()), null, Shader.TileMode.CLAMP)
            canvas.drawCircle(direction * r * .34f, 0f, r * .155f, paint)
        }
        paint.shader = null; paint.color = 0xffe6c980.toInt()
        for (p in listOf(-.45f to -.24f, 0f to -.52f, .45f to -.24f, .1f to .47f)) canvas.drawCircle(p.first * r, p.second * r, 2f, paint)
        canvas.restore(); paint.style = Paint.Style.STROKE; paint.strokeWidth = 1.8f; paint.color = 0xffa6a6a6.toInt(); canvas.drawPath(path, paint)
        paint.style = Paint.Style.FILL; canvas.restore()
    }

    private fun calendar(canvas: Canvas, scale: Float, now: Long) {
        canvas.save(); canvas.translate(246.176f, 180f); canvas.scale(scale, scale)
        val rect = RectF(-44.6688f, -19.4392f, 44.6688f, 19.4392f)
        paint.shader = LinearGradient(rect.left, rect.top, rect.right, rect.bottom, intArrayOf(0xffd7d1c5.toInt(), 0xfffffef8.toInt()), null, Shader.TileMode.CLAMP)
        canvas.drawRoundRect(rect, 5.8f, 5.8f, paint); paint.shader = null
        paint.style = Paint.Style.STROKE; paint.strokeWidth = 2.65f; paint.color = 0xffa6a6a6.toInt(); canvas.drawRoundRect(rect, 5.8f, 5.8f, paint); paint.style = Paint.Style.FILL
        paint.strokeWidth = 1.3f; canvas.drawLine(9.827f, -13f, 9.827f, 13f, paint)
        val calendar = Calendar.getInstance().apply { timeInMillis = now }
        text(canvas, "周" + "日一二三四五六"[calendar.get(Calendar.DAY_OF_WEEK) - 1], -17.42f, 0f, 22.33f, 0xff2b3035.toInt(), true)
        text(canvas, String.format(Locale.US, "%02d", calendar.get(Calendar.DAY_OF_MONTH)), 27.24f, 0f, 22.33f, 0xff2b3035.toInt(), true)
        canvas.restore()
    }

    /** 保留参考中的透明玻璃底座，天气只读取真实缓存；不伪造摄取桌面壁纸的实时模糊。 */
    fun manila(context: Context, now: Long): Bitmap {
        resetPaint()
        val result = Bitmap.createBitmap(540, 375, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result).apply { scale(1.5f, 1.5f) }
        paint.shader = LinearGradient(0f, 16f, 360f, 230f, intArrayOf(0x65e8f0f4, 0x453c4852, 0x95313a43.toInt()), null, Shader.TileMode.CLAMP)
        canvas.drawRoundRect(RectF(0f, 16f, 360f, 230f), 9f, 9f, paint); paint.shader = null
        paint.style = Paint.Style.STROKE; paint.color = 0x70ffffff; paint.strokeWidth = .7f; canvas.drawRoundRect(RectF(0f, 16f, 360f, 230f), 9f, 9f, paint); paint.style = Paint.Style.FILL
        for (left in listOf(20f, 198f)) {
            paint.shader = LinearGradient(0f, 0f, 0f, 164f, intArrayOf(0xfff7f8f4.toInt(), 0xffdde1db.toInt(), 0xfffafbf7.toInt(), 0xffe8ece7.toInt()), floatArrayOf(0f, .498f, .502f, 1f), Shader.TileMode.CLAMP)
            canvas.drawRoundRect(RectF(left, 0f, left + 142, 164f), 5f, 5f, paint); paint.shader = null
            paint.color = 0x60000000; canvas.drawRect(left, 81.55f, left + 142, 82.45f, paint)
        }
        val settings = ClockStore.settings(context); val weather = ClockStore.weather(context)
        text(canvas, settings.city, 12f, 184f, 13f, Color.WHITE, false, Paint.Align.LEFT)
        text(canvas, weather?.label ?: "暂无天气", 12f, 204f, 12f, Color.WHITE, false, Paint.Align.LEFT)
        val day = Calendar.getInstance().apply { timeInMillis = now }
        val label = "周${"日一二三四五六"[day.get(Calendar.DAY_OF_WEEK) - 1]}，${day.get(Calendar.MONTH) + 1}月${day.get(Calendar.DAY_OF_MONTH)}日"
        text(canvas, label, 348f, 181f, 10f, Color.WHITE, false, Paint.Align.RIGHT)
        text(canvas, weather?.let { "${it.temperature.toInt()}°" } ?: "—°", 290f, 210f, 30f, Color.WHITE, false, Paint.Align.RIGHT)
        text(canvas, "高 ${weather?.high?.toInt() ?: "—"}°", 348f, 201f, 10f, Color.WHITE, false, Paint.Align.RIGHT)
        text(canvas, "低 ${weather?.low?.toInt() ?: "—"}°", 348f, 217f, 10f, Color.WHITE, false, Paint.Align.RIGHT)
        text(canvas, if (weather?.stale == true) "上次天气 · Open-Meteo" else "Open-Meteo", 12f, 240f, 8f, 0xbbffffff.toInt(), false, Paint.Align.LEFT)
        weatherIcon(canvas, weather?.code ?: 3, weather?.isDay ?: true)
        return result
    }

    private fun weatherIcon(canvas: Canvas, code: Int, isDay: Boolean) {
        paint.color = Color.WHITE
        canvas.save(); canvas.translate(124f, 160f); canvas.scale(1.12f, .94f)
        if (code < 3) {
            val x = if (code == 0) 50f else 65f; val y = if (code == 0) 40f else 27f
            paint.color = 0xfff5b735.toInt(); paint.strokeWidth = 2f
            if (isDay) for (i in 0..11) {
                val angle = i * PI / 6
                canvas.drawLine(x + cos(angle).toFloat() * 25, y + sin(angle).toFloat() * 25, x + cos(angle).toFloat() * 31, y + sin(angle).toFloat() * 31, paint)
            }
            paint.shader = RadialGradient(x - 5, y - 5, 28f, intArrayOf(0xfffff1a5.toInt(), if (isDay) 0xffe78717.toInt() else 0xffc9cfde.toInt()), null, Shader.TileMode.CLAMP)
            canvas.drawCircle(x, y, 23f, paint); paint.shader = null
        }
        if (code != 0) {
            val cloud = Path().apply { moveTo(15f, 64f); cubicTo(-1f, 61f, 2f, 41f, 20f, 41f); cubicTo(19f, 17f, 54f, 13f, 62f, 36f); cubicTo(85f, 29f, 99f, 59f, 78f, 65f); close() }
            paint.shader = LinearGradient(0f, 20f, 0f, 70f, intArrayOf(Color.WHITE, 0xff9caabb.toInt()), null, Shader.TileMode.CLAMP); canvas.drawPath(cloud, paint); paint.shader = null
            if (code >= 51) { paint.color = 0xff86bdf7.toInt(); paint.strokeWidth = 3f; for (i in 0..3) canvas.drawLine(25f + i * 15, 70f, 21f + i * 15, 79f, paint) }
        }
        canvas.restore()
    }

    private fun text(canvas: Canvas, value: String, x: Float, y: Float, size: Float, color: Int, bold: Boolean, align: Paint.Align = Paint.Align.CENTER) {
        paint.color = color; paint.textSize = size; paint.typeface = Typeface.create("sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL); paint.textAlign = align
        canvas.drawText(value, x, y - (paint.fontMetrics.ascent + paint.fontMetrics.descent) / 2, paint)
    }

    /** Paint.color 同时携带 alpha，不能让天气归属文字的半透明状态污染下一张机械表。 */
    private fun resetPaint() { paint.reset(); paint.isAntiAlias = true; paint.isFilterBitmap = true }
}
