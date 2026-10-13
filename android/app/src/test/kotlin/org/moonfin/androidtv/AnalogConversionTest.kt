package org.moonfin.androidtv

import android.view.MotionEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalogConversionTest {
    @Test
    fun `centre reports zero`() {
        assertEquals(packAxes(0, 0), analogAxisPair(0f, 0f))
    }

    @Test
    fun `a value inside the dead zone reports zero`() {
        assertEquals(packAxes(0, 0), analogAxisPair(0.01f, 0f))
        assertEquals(packAxes(0, 0), analogAxisPair(0f, -0.015f))
    }

    @Test
    fun `full deflection reaches the rail`() {
        // Proves the rescale: without it, full deflection would clip at
        // (1 - ANALOG_DEAD_ZONE) * 32767 instead of reaching it.
        assertEquals(packAxes(32767, 0), analogAxisPair(1f, 0f))
    }

    @Test
    fun `full negative deflection reaches the negative rail`() {
        val packed = analogAxisPair(-1f, 0f)
        val x = axisX(packed)
        assertEquals(-32767, x)
    }

    @Test
    fun `just outside the dead zone is a small value, not a jump to full scale`() {
        // The dead zone is 0.02; 0.03 is barely past it, so the rescaled
        // result should be a small fraction of the rail, not near it.
        val packed = analogAxisPair(0.03f, 0f)
        val x = axisX(packed)
        assertTrue("expected a small non-zero value, got $x", x in 1..3000)
    }

    @Test
    fun `a diagonal stays diagonal and does not exceed the rails`() {
        val packed = analogAxisPair(0.707f, 0.707f)
        val x = axisX(packed)
        val y = axisY(packed)
        assertTrue(x > 0)
        assertTrue(y > 0)
        // Roughly equal magnitude on both axes (diagonal preserved).
        assertTrue(Math.abs(x - y) < 200)
        assertTrue(x <= 32767)
        assertTrue(y <= 32767)
    }

    @Test
    fun `trigger at rest reports zero`() {
        assertEquals(0, analogTrigger(0f))
    }

    @Test
    fun `trigger fully pressed reaches 0x7fff`() {
        assertEquals(0x7fff, analogTrigger(1f))
    }

    @Test
    fun `trigger inside the dead zone reports zero`() {
        assertEquals(0, analogTrigger(0.01f))
    }

    @Test
    fun `trigger axis resolution picks BRAKE and GAS when LTRIGGER and RTRIGGER are unused`() {
        val declared = setOf(MotionEvent.AXIS_BRAKE, MotionEvent.AXIS_GAS)
        val axes = TriggerAxisResolver.resolve { it in declared }
        assertEquals(MotionEvent.AXIS_BRAKE, axes.left)
        assertEquals(MotionEvent.AXIS_GAS, axes.right)
    }

    @Test
    fun `trigger axis resolution picks LTRIGGER and RTRIGGER when the device declares those`() {
        val declared = setOf(MotionEvent.AXIS_LTRIGGER, MotionEvent.AXIS_RTRIGGER)
        val axes = TriggerAxisResolver.resolve { it in declared }
        assertEquals(MotionEvent.AXIS_LTRIGGER, axes.left)
        assertEquals(MotionEvent.AXIS_RTRIGGER, axes.right)
    }

    // --- gentle 8-way snap (SNAP_DEGREES) ---

    private fun atDegrees(degrees: Double, magnitude: Float = 0.9f): Long {
        val r = Math.toRadians(degrees)
        return analogAxisPair(
            (Math.cos(r) * magnitude).toFloat(),
            (Math.sin(r) * magnitude).toFloat(),
        )
    }

    @Test
    fun `input just off a cardinal snaps onto it`() {
        // Measured on device: holding "up" sits a median ~14 degrees off axis.
        // Inside the 10 degree window the minor component must vanish.
        val packed = atDegrees(95.0)
        assertEquals("minor component should be dropped", 0, axisX(packed))
        assertTrue("major component should survive", axisY(packed) > 20000)
    }

    @Test
    fun `input well off a cardinal is left alone`() {
        // 20 degrees off is outside the window: this is a real diagonal-ish
        // push and must not be flattened, or an 8-way game loses input.
        val packed = atDegrees(70.0)
        assertTrue("expected the minor component to survive", axisX(packed) > 1000)
    }

    @Test
    fun `input just off a diagonal snaps onto it`() {
        val packed = atDegrees(40.0)
        val x = axisX(packed)
        val y = axisY(packed)
        assertTrue("expected equal components, got $x/$y", Math.abs(x - y) <= 2)
    }

    @Test
    fun `a snapped diagonal keeps its magnitude and stays inside the rails`() {
        val packed = analogAxisPair(1f, 1f)
        val x = axisX(packed)
        val y = axisY(packed)
        assertTrue("x out of range: $x", x in 22000..32767)
        assertTrue("y out of range: $y", y in 22000..32767)
    }

    @Test
    fun `the snap preserves sign in every quadrant`() {
        for (degrees in listOf(95.0, 175.0, 265.0, 355.0, 40.0, 130.0, 220.0, 310.0)) {
            val r = Math.toRadians(degrees)
            val rawX = (Math.cos(r) * 0.9).toFloat()
            val rawY = (Math.sin(r) * 0.9).toFloat()
            val packed = analogAxisPair(rawX, rawY)
            val x = axisX(packed)
            val y = axisY(packed)
            if (Math.abs(rawX) > 0.2f) {
                assertTrue("x sign flipped at $degrees", (x > 0) == (rawX > 0))
            }
            if (Math.abs(rawY) > 0.2f) {
                assertTrue("y sign flipped at $degrees", (y > 0) == (rawY > 0))
            }
        }
    }

    @Test
    fun `the snap never resurrects a dead-zone value`() {
        assertEquals(packAxes(0, 0), analogAxisPair(0.014f, 0.014f))
    }

    // --- snap modes ---

    private fun snapAt(degrees: Double, mode: StickSnap): Pair<Float, Float> {
        val r = Math.toRadians(degrees)
        val packed = snapAxes(
            (Math.cos(r) * 0.9).toFloat(),
            (Math.sin(r) * 0.9).toFloat(),
            mode,
        )
        return snapX(packed) to snapY(packed)
    }

    @Test
    fun `four-way always drops the weaker axis`() {
        // 31 degrees is the p90 drift measured while holding "up"; 4-way must
        // still resolve it to a pure cardinal or a ladder stalls.
        val (x, y) = snapAt(59.0, StickSnap.FOUR_WAY)
        assertEquals(0f, x)
        assertTrue("expected the major axis to survive, got $y", y > 0.7f)
    }

    @Test
    fun `four-way keeps a deliberate diagonal off the diagonal`() {
        val (x, y) = snapAt(45.0, StickSnap.FOUR_WAY)
        assertTrue("one axis must win outright", x == 0f || y == 0f)
    }

    @Test
    fun `eight-way keeps diagonals and cleans cardinals`() {
        val (dx, dy) = snapAt(40.0, StickSnap.EIGHT_WAY)
        assertTrue("expected a diagonal, got $dx/$dy", Math.abs(dx - dy) < 0.01f)

        val (cx, cy) = snapAt(80.0, StickSnap.EIGHT_WAY)
        assertEquals(0f, cx)
        assertTrue("expected the major axis to survive, got $cy", cy > 0.7f)
    }

    @Test
    fun `off leaves a 31 degree lean alone`() {
        // The gentle default only corrects small drift; anything larger is
        // the per-game 4-way setting's job.
        val (x, y) = snapAt(59.0, StickSnap.OFF)
        assertTrue("expected the minor axis to survive, got $x", x > 0.1f)
        assertTrue(y > 0.1f)
    }

    @Test
    fun `snap mode wire names round-trip`() {
        for (mode in StickSnap.entries) {
            assertEquals(mode, StickSnap.fromWireName(mode.wireName))
        }
        assertEquals(StickSnap.OFF, StickSnap.fromWireName("nonsense"))
        assertEquals(StickSnap.OFF, StickSnap.fromWireName(null))
    }
}
