package com.xiongjian.widget

import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor

/** 不可变快照；任何损坏、非有限数或越界输入都回退/夹取，桌面进程不接收未校验 JSON。 */
data class ClockSettings(
    val moonScale: Double = 1.0, val calendarScale: Double = 1.0, val romanScale: Double = 1.0,
    val city: String = "北京", val latitude: Double = 39.9042, val longitude: Double = 116.4074,
) {
    val cityKey: String get() = String.format(Locale.US, "%.4f,%.4f", latitude, longitude)
    val dialKey: Int get() = (romanScale * 1000).toInt()
    companion object {
        fun parse(raw: String?): ClockSettings {
            val json = runCatching { JSONObject(raw ?: "{}") }.getOrNull() ?: return ClockSettings()
            fun scale(key: String) = json.optDouble(key, 1.0).let { if (it.isFinite()) it.coerceIn(.5, 1.5) else 1.0 }
            val city = json.optJSONObject("city")
            val lat = city?.optDouble("latitude", Double.NaN) ?: Double.NaN
            val lon = city?.optDouble("longitude", Double.NaN) ?: Double.NaN
            val name = city?.optString("name")?.takeIf { it.isNotBlank() && it.length <= 100 }
            val valid = name != null && lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0
            return ClockSettings(scale("moonScale"), scale("calendarScale"), scale("romanScale"),
                if (valid) name ?: "北京" else "北京", if (valid) lat else 39.9042, if (valid) lon else 116.4074)
        }
    }
}

/** 与 App 一致的绝对时间数学。动画只在当前分钟边界播放，绝不累加角度或补播睡眠期间翻页。 */
object ClockTime {
    const val FLIP_MS = 640L
    fun untilNextMinute(now: Long): Long = 60_000L - Math.floorMod(now, 60_000L)
    fun beat(now: Long): Int = Math.floorMod(now / 125, 2L).toInt()
    fun moon(now: Long): Double {
        val cycles = (now / 1000.0 - 1712600460) / (86400 * 29.530589)
        return cycles - floor(cycles)
    }
    fun handTurns(now: Long, zone: TimeZone = TimeZone.getDefault()): Triple<Double, Double, Double> {
        val seconds = (now + zone.getOffset(now)) / 1000.0
        fun turns(period: Double) = seconds / period - floor(seconds / period)
        return Triple(turns(43200.0), turns(3600.0), turns(60.0))
    }
    fun labels(now: Long): Pair<String, String> {
        val date = java.util.Date(now)
        return SimpleDateFormat("HH", Locale.US).format(date) to SimpleDateFormat("mm", Locale.US).format(date)
    }
    /** 透视投影四点：上下半页共用中轴，保留随角度变化的远近宽度，不能退化为 scaleY。 */
    fun projectedHalf(width: Float, height: Float, angle: Double, top: Boolean): FloatArray {
        val radians = angle * PI / 180
        val edge = if (top) -height else height
        fun point(x: Float, y: Float): Pair<Float, Float> {
            val z = y * kotlin.math.sin(radians)
            val perspective = (1.0 / (1.0 + .003 * z)).toFloat()
            return width / 2 + (x - width / 2) * perspective to (y * cos(radians) * perspective).toFloat()
        }
        val a = point(0f, if (top) edge else 0f)
        val b = point(width, if (top) edge else 0f)
        val c = point(width, if (top) 0f else edge)
        val d = point(0f, if (top) 0f else edge)
        return floatArrayOf(a.first, a.second, b.first, b.second, c.first, c.second, d.first, d.second)
    }
}

/** 天气只保存真实值和获取时间，城市发生变化时不把旧缓存显示到新城市。 */
data class ClockWeather(val cityKey: String, val temperature: Double, val code: Int, val isDay: Boolean, val fetchedAt: Long, val high: Double?, val low: Double?) {
    val stale: Boolean get() = System.currentTimeMillis() - fetchedAt > 45 * 60_000
    val label: String get() = when (code) { 0 -> "晴"; 1, 2 -> "晴间多云"; 3 -> "阴"; 45, 48 -> "雾"; in 51..67, in 80..82 -> "雨"; in 71..77, in 85..86 -> "雪"; in 95..99 -> "雷雨"; else -> "天气" }
    companion object {
        fun parse(raw: String?): ClockWeather? = runCatching {
            val json = JSONObject(raw ?: return null)
            val value = json.getDouble("temperature")
            val code = json.getInt("code")
            if (!value.isFinite() || code !in 0..99) return null
            val rawDate = json.getString("fetchedAt").replace(Regex("\\.(\\d{3})\\d+"), ".$1")
            val date = listOf("yyyy-MM-dd'T'HH:mm:ss.SSSX", "yyyy-MM-dd'T'HH:mm:ssX").firstNotNullOfOrNull {
                runCatching { SimpleDateFormat(it, Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.parse(rawDate) }.getOrNull()
            } ?: return null
            fun optional(key: String): Double? = json.optDouble(key).takeIf { it.isFinite() }
            ClockWeather(json.getString("cityKey"), value, code, json.optBoolean("isDay", true), date.time, optional("high"), optional("low"))
        }.getOrNull()
    }
}
