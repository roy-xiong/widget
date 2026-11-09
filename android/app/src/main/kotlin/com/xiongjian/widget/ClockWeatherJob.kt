package com.xiongjian.widget

import android.app.job.*
import android.content.ComponentName
import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.Future

/** 系统周期任务只更新天气/日历，不驱动动画。网络线程不持有 Activity，不访问任何 View。 */
class ClockWeatherJob : JobService() {
    private val executor = Executors.newSingleThreadExecutor()
    private var task: Future<*>? = null
    override fun onStartJob(params: JobParameters?): Boolean {
        val app = applicationContext
        task = executor.submit {
            try {
                val settings = ClockStore.settings(app)
                val cached = ClockStore.weather(app)
                if (cached == null || System.currentTimeMillis() - cached.fetchedAt > 15 * 60_000) {
                    val connection = URL("https://api.open-meteo.com/v1/forecast?latitude=${settings.latitude}&longitude=${settings.longitude}&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto").openConnection() as? HttpURLConnection
                    if (connection != null) try {
                        connection.connectTimeout = 8000; connection.readTimeout = 8000
                        if (connection.responseCode == 200) {
                            val bytes = connection.inputStream.use { stream ->
                                val output = java.io.ByteArrayOutputStream(); val buffer = ByteArray(2048)
                                while (true) { if (Thread.interrupted()) throw InterruptedException(); val count = stream.read(buffer); if (count < 0) break; require(output.size() + count <= 65536); output.write(buffer, 0, count) }
                                output.toByteArray()
                            }
                            val json = JSONObject(String(bytes, Charsets.UTF_8)); val current = json.getJSONObject("current")
                            val temperature = current.getDouble("temperature_2m"); val code = current.getInt("weather_code")
                            require(temperature.isFinite() && code in 0..99)
                            val stamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(java.util.Date())
                            val result = JSONObject().put("cityKey", settings.cityKey).put("temperature", temperature).put("code", code).put("isDay", current.optInt("is_day", 1) == 1).put("fetchedAt", stamp)
                            val daily = json.optJSONObject("daily")
                            for ((key, source) in listOf("high" to "temperature_2m_max", "low" to "temperature_2m_min")) daily?.optJSONArray(source)?.optDouble(0)?.takeIf { it.isFinite() }?.let { result.put(key, it) }
                            ClockTasks.execute { if (ClockStore.settings(app).cityKey == settings.cityKey) ClockStore.write(app, "weather", result.toString()) }
                        }
                    } finally { connection.disconnect() }
                }
            } catch (_: Exception) { /* 离线保留带获取时间的缓存；不将错误写成假温度。 */ }
            finally { ClockTasks.execute { WidgetRenderer.updateAll(app); jobFinished(params, false) } }
        }
        return true
    }
    override fun onStopJob(params: JobParameters?): Boolean { task?.cancel(true); return true }
    override fun onDestroy() { task?.cancel(true); executor.shutdownNow(); super.onDestroy() }
    companion object {
        private const val PERIODIC = 4801
        fun schedule(context: Context) {
            val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
            val component = ComponentName(context, ClockWeatherJob::class.java)
            if (scheduler.getPendingJob(PERIODIC) == null) scheduler.schedule(JobInfo.Builder(PERIODIC, component).setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPeriodic(30 * 60_000L).setPersisted(true).build())
            if (ClockStore.weather(context) == null && scheduler.getPendingJob(PERIODIC + 1) == null) scheduler.schedule(JobInfo.Builder(PERIODIC + 1, component).setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setMinimumLatency(1000).build())
        }
        fun cancel(context: Context) { context.getSystemService(JobScheduler::class.java)?.let { it.cancel(PERIODIC); it.cancel(PERIODIC + 1) } }
    }
}
