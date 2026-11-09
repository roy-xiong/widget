package com.xiongjian.widget

import org.junit.Assert.*
import org.junit.Test
import java.util.TimeZone
import kotlin.math.abs

class ClockTimeTest {
    @Test fun minuteBoundaryDoesNotAccumulateDelay() {
        assertEquals(1L, ClockTime.untilNextMinute(59999))
        assertEquals(60000L, ClockTime.untilNextMinute(60000))
        assertEquals(1L, ClockTime.untilNextMinute(-1))
        assertEquals(0, ClockTime.beat(0)); assertEquals(1, ClockTime.beat(125)); assertEquals(0, ClockTime.beat(250))
    }
    @Test fun handsUseSystemTimeZoneAndFractionalSeconds() {
        val (hour, minute, second) = ClockTime.handTurns(1815125, TimeZone.getTimeZone("GMT+08:00"))
        assertEquals(8.5042013889 / 12, hour, .000001)
        assertEquals(30.25208333 / 60, minute, .000001)
        assertEquals(15.125 / 60, second, .000001)
        assertTrue(ClockTime.moon(1712600460000) < .00001)
    }
    @Test fun foldingHasPerspectiveRatherThanOnlyVerticalScaling() {
        val projected = ClockTime.projectedHalf(142f, 82f, -45.0, true)
        val topWidth = projected[2] - projected[0]
        val axisWidth = projected[4] - projected[6]
        assertTrue("Depth must change the remote edge width", abs(topWidth - axisWidth) > 10)
        assertEquals(142f, axisWidth, .001f)
        assertEquals(0f, projected[5], .001f)
    }
}
