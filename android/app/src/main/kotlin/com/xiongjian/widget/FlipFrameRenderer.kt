package com.xiongjian.widget

import android.graphics.*
import kotlin.math.PI
import kotlin.math.sin

/** 与 Flutter 翻页相同的 640ms 两阶段动作；使用四点透视投影，远端宽度随深度改变。 */
object FlipFrameRenderer {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    /** 只为发生变化的时/分牌生成透明覆盖层；稳定时间始终由底层 TextClock 驱动。 */
    fun render(old: Pair<String, String>, next: Pair<String, String>, progress: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(540, 375, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap).apply { scale(1.5f, 1.5f) }
        if (old.first != next.first) tile(canvas, 20f, old.first, next.first, progress.coerceIn(0f, 1f))
        if (old.second != next.second) tile(canvas, 198f, old.second, next.second, progress.coerceIn(0f, 1f))
        return bitmap
    }

    private fun face(value: String): Bitmap {
        val result = Bitmap.createBitmap(284, 328, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result).apply { scale(2f, 2f) }
        paint.style = Paint.Style.FILL; paint.textAlign = Paint.Align.CENTER; paint.textScaleX = 1f
        paint.shader = LinearGradient(0f, 0f, 0f, 164f, intArrayOf(0xfff7f8f4.toInt(), 0xffdde1db.toInt(), 0xfffafbf7.toInt(), 0xffe8ece7.toInt()), floatArrayOf(0f, .498f, .502f, 1f), Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, 142f, 164f, paint); paint.shader = null
        paint.color = 0xff232627.toInt(); paint.typeface = Typeface.create("sans-serif-light", Typeface.NORMAL); paint.textSize = 139f; paint.textScaleX = .78f
        canvas.drawText(value, 71f, 82f - (paint.fontMetrics.ascent + paint.fontMetrics.descent) / 2, paint)
        paint.textScaleX = 1f
        return result
    }

    private fun tile(canvas: Canvas, left: Float, oldValue: String, nextValue: String, t: Float) {
        val old = face(oldValue); val next = face(nextValue)
        canvas.save(); canvas.translate(left, 0f); canvas.clipRect(0f, 0f, 142f, 164f)
        canvas.drawBitmap(next, Rect(0, 0, 284, 164), RectF(0f, 0f, 142f, 82f), paint)
        canvas.drawBitmap(if (t < 1) old else next, Rect(0, 164, 284, 328), RectF(0f, 82f, 142f, 164f), paint)
        if (t < .5f) {
            // easeIn 的近似单调曲线只改变角度，不把三维变换降成二维压缩。
            val u = t * 2; half(canvas, old, -90.0 * u * u, true)
        } else if (t < 1f) {
            val u = (t - .5f) * 2; half(canvas, next, 90.0 * (1 - u) * (1 - u) * (1 - u), false)
        }
        paint.color = 0x60000000; canvas.drawRect(0f, 81.55f, 142f, 82.45f, paint)
        paint.color = 0xff777777.toInt(); canvas.drawRoundRect(RectF(0f, 78.5f, 2.5f, 85.5f), 1f, 1f, paint); canvas.drawRoundRect(RectF(139.5f, 78.5f, 142f, 85.5f), 1f, 1f, paint)
        canvas.restore(); old.recycle(); next.recycle()
    }

    private fun half(canvas: Canvas, image: Bitmap, angle: Double, top: Boolean) {
        // 完全侧向时面积极小，四点投影矩阵不可逆；这一瞬间只显示底层半牌。
        if (kotlin.math.abs(kotlin.math.cos(angle * PI / 180)) < .0001) return
        val half = Bitmap.createBitmap(image, 0, if (top) 0 else 164, 284, 164)
        val source = floatArrayOf(0f, 0f, 284f, 0f, 284f, 164f, 0f, 164f)
        val target = ClockTime.projectedHalf(142f, 82f, angle, top)
        val matrix = Matrix(); check(matrix.setPolyToPoly(source, 0, target, 0, 4))
        canvas.save(); canvas.translate(0f, 82f); canvas.drawBitmap(half, matrix, paint)
        // 折页在倾斜时变暗，与转轴和透视一起呈现翻折，不依赖屏幕外的自定义 View。
        paint.color = Color.argb((55 * kotlin.math.abs(sin(angle * PI / 180))).toInt(), 0, 0, 0)
        val shadow = Path().apply { moveTo(target[0], target[1]); for (i in 1..3) lineTo(target[i * 2], target[i * 2 + 1]); close() }
        canvas.drawPath(shadow, paint); canvas.restore(); half.recycle()
    }
}
