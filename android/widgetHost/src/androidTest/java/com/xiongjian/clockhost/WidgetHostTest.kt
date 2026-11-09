package com.xiongjian.clockhost

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.ViewFlipper
import android.widget.ImageView
import android.widget.TextClock
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.atomic.AtomicReference

/** 验证真实跨进程宿主，禁止用 App 内普通预览代替桌面组件。 */
@RunWith(AndroidJUnit4::class)
class WidgetHostTest {
    @Test fun realHostPlaysBalanceAndPerspectiveFlip() {
        ActivityScenario.launch(HostActivity::class.java).use { scenario ->
            val instrumentation = InstrumentationRegistry.getInstrumentation()
            val provider = instrumentation.targetContext.createPackageContext("com.xiongjian.widget", 0)
            fun id(name: String) = provider.resources.getIdentifier(name, "id", provider.packageName)
            fun <T> onHost(block: (HostActivity) -> T): T {
                val result = AtomicReference<T>()
                scenario.onActivity { result.set(block(it)) }
                return result.get()
            }
            fun await(timeout: Long = 8000, predicate: () -> Boolean) {
                val end = System.currentTimeMillis() + timeout
                while (!predicate()) { check(System.currentTimeMillis() < end) { "Host condition timed out" }; Thread.sleep(40) }
            }
            fun capture(name: String, mechanical: Boolean): Bitmap = onHost { activity ->
                val view = activity.views[mechanical] ?: error("Missing widget")
                Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also { image ->
                    view.draw(Canvas(image))
                    val folder = File(activity.getExternalFilesDir(null), "qa").apply { mkdirs() }
                    File(folder, "$name.png").outputStream().use { image.compress(Bitmap.CompressFormat.PNG, 100, it) }
                }
            }
            fun command(name: String, raw: String? = null) {
                val context = instrumentation.targetContext
                context.startActivity(Intent().setClassName("com.xiongjian.widget", "com.xiongjian.widget.WidgetProbeActivity")
                    .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("command", name).putExtra("settings", raw))
            }
            await { onHost { it.views[true]?.findViewById<ViewFlipper>(id("balance_flipper")) != null && it.views[false]?.findViewById<TextClock>(id("clock_minute_text")) != null } }
            Thread.sleep(800)
            val initial = onHost { it.views[true]!!.findViewById<ViewFlipper>(id("balance_flipper")).displayedChild }
            await(1500) { onHost { it.views[true]!!.findViewById<ViewFlipper>(id("balance_flipper")).displayedChild != initial } }
            val first = capture("mechanical-before", true)
            Thread.sleep(1200)
            val second = capture("mechanical-after", true)
            assertFalse("System hands must move in the real host", first.sameAs(second))
            capture("manila-idle", false)
            command("preview")
            await(8000) { onHost { it.views[false]?.findViewById<ImageView>(id("flip_overlay"))?.visibility == View.VISIBLE } }
            val flip1 = capture("flip-start", false)
            Thread.sleep(160)
            val flip2 = capture("flip-middle", false)
            assertFalse("Perspective flip must produce changing host pixels", flip1.sameAs(flip2))
            await { onHost { it.views[false]?.findViewById<ImageView>(id("flip_overlay"))?.visibility == View.GONE } }
            command("settings", "{\"moonScale\":1.5,\"calendarScale\":0.5,\"romanScale\":1}")
            Thread.sleep(800)
            val resized = capture("mechanical-custom-sizes", true)
            assertFalse("Component settings must change actual widget pixels", second.sameAs(resized))
            command("stop")
            Thread.sleep(500)
            assertEquals(View.GONE, onHost { it.views[false]!!.findViewById<ImageView>(id("flip_overlay")).visibility })
            println("PASS: actual cross-process AppWidgetHost, autonomous balance, moving hands, 3D flip, settings and stop")
        }
    }
}
