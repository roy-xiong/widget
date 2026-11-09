package com.xiongjian.clockhost

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
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
            fun face(): Bitmap = onHost { activity ->
                val drawable = activity.views[true]!!.findViewById<ImageView>(id("clock_face")).drawable as BitmapDrawable
                drawable.bitmap.copy(Bitmap.Config.ARGB_8888, false)
            }
            fun hands(): Bitmap = onHost { activity ->
                val view = activity.views[true]!!.findViewById<View>(id("clock_hands"))
                Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
            }
            fun changed(a: Bitmap, b: Bitmap, left: Int, top: Int, right: Int, bottom: Int): Int {
                var count = 0
                for (y in top * a.height / 360 until bottom * a.height / 360) for (x in left * a.width / 360 until right * a.width / 360) {
                    if (a.getPixel(x, y) != b.getPixel(x, y)) count++
                }
                return count
            }
            await { onHost { it.views[true]?.findViewById<ViewFlipper>(id("balance_flipper")) != null && it.views[false]?.findViewById<TextClock>(id("clock_minute_text")) != null } }
            Thread.sleep(800)
            val initial = onHost { it.views[true]!!.findViewById<ViewFlipper>(id("balance_flipper")).displayedChild }
            await(1500) { onHost { it.views[true]!!.findViewById<ViewFlipper>(id("balance_flipper")).displayedChild != initial } }
            capture("mechanical-before", true)
            val firstHands = hands()
            Thread.sleep(1200)
            capture("mechanical-after", true)
            assertFalse("System hands must move independently of the balance flipper", firstHands.sameAs(hands()))
            capture("manila-idle", false)
            command("preview")
            await(8000) { onHost { it.views[false]?.findViewById<ImageView>(id("flip_overlay"))?.visibility == View.VISIBLE } }
            val flip1 = capture("flip-start", false)
            Thread.sleep(160)
            val flip2 = capture("flip-middle", false)
            assertFalse("Perspective flip must produce changing host pixels", flip1.sameAs(flip2))
            await { onHost { it.views[false]?.findViewById<ImageView>(id("flip_overlay"))?.visibility == View.GONE } }
            command("settings", "{}")
            Thread.sleep(800)
            val baseline = face()
            assertEquals("Weather alpha must not leak into the next mechanical face", 255, Color.alpha(baseline.getPixel(baseline.width / 2, baseline.height / 2)))
            for ((name, raw, region) in listOf(
                Triple("moon", "{\"moonScale\":1.5}", intArrayOf(120, 50, 240, 140)),
                Triple("calendar", "{\"calendarScale\":0.5}", intArrayOf(175, 140, 320, 220)),
                Triple("roman", "{\"romanScale\":1.5}", intArrayOf(135, 25, 225, 70)),
            )) {
                command("settings", raw)
                await { val next = face(); changed(baseline, next, region[0], region[1], region[2], region[3]) > 200 }
                capture("mechanical-size-$name", true)
            }
            command("stop")
            Thread.sleep(500)
            assertEquals(View.GONE, onHost { it.views[false]!!.findViewById<ImageView>(id("flip_overlay")).visibility })
            println("PASS: actual cross-process AppWidgetHost, autonomous balance, moving hands, 3D flip, settings and stop")
        }
    }
}
