package com.xiongjian.widget

import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/** 所有小组件位图、设置和 Provider 更新在单一队列串行执行；只捕获 ApplicationContext。 */
object ClockTasks {
    private val executor = Executors.newSingleThreadExecutor { task -> Thread(task, "clock-widget-files").apply { isDaemon = true } }
    fun execute(block: () -> Unit) { executor.execute { runCatching(block).onFailure { android.util.Log.e("ClockWidget", "Widget update failed", it) } } }
}

/** App 与 Provider 同包共享原子偏好。先提交对应底图，再提交设置，避免独立滑杆被图像缓存跳过。 */
object ClockStore {
    private fun prefs(context: Context) = context.getSharedPreferences("desktop-clock", Context.MODE_PRIVATE)
    fun read(context: Context, key: String): String? = prefs(context).getString(key, null)
    fun settings(context: Context): ClockSettings = ClockSettings.parse(read(context, "settings"))
    fun weather(context: Context): ClockWeather? = ClockWeather.parse(read(context, "weather"))?.takeIf { it.cityKey == settings(context).cityKey }
    fun animations(context: Context): Boolean = prefs(context).getBoolean("animations", false)
    fun setAnimations(context: Context, enabled: Boolean) { prefs(context).edit().putBoolean("animations", enabled).apply() }
    fun write(context: Context, key: String, raw: String?) {
        require(key in setOf("settings", "weather") && raw != null && raw.toByteArray().size <= 131072)
        JSONObject(raw)
        check(prefs(context).edit().putString(key, raw).commit())
    }
    fun dial(context: Context, settings: ClockSettings): File = File(context.filesDir, "motion-dial-${settings.dialKey}.png")
    fun publish(context: Context, raw: String?, png: ByteArray?) {
        require(raw != null && raw.toByteArray().size <= 131072)
        JSONObject(raw)
        val settings = ClockSettings.parse(raw)
        if (png != null) {
            require(png.size <= 1048576 && png.take(8) == listOf(137, 80, 78, 71, 13, 10, 26, 10).map { it.toByte() })
            val file = AtomicFile(dial(context, settings))
            val stream = file.startWrite()
            try { stream.write(png); file.finishWrite(stream) } catch (error: Exception) { file.failWrite(stream); throw error }
        }
        write(context, "settings", raw)
    }
}
