package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BurstCoalescerTest {

    @Test
    fun `a lone event fires one debounce later`() {
        val coalescer = BurstCoalescer(debounceMs = 750, maxWaitMs = 3_000)
        assertEquals(1_750, coalescer.onEvent(1_000))
    }

    @Test
    fun `a burst collapses to one trailing fire`() {
        // The caller cancels the previous runnable on every event, so only
        // the last of these times is ever reached.
        val coalescer = BurstCoalescer(debounceMs = 750, maxWaitMs = 3_000)
        assertEquals(750, coalescer.onEvent(0))
        assertEquals(1_250, coalescer.onEvent(500))
        assertEquals(1_750, coalescer.onEvent(1_000))
    }

    @Test
    fun `the max wait caps a source that keeps flapping`() {
        val coalescer = BurstCoalescer(debounceMs = 750, maxWaitMs = 3_000)
        assertEquals(750, coalescer.onEvent(0))
        assertEquals(3_000, coalescer.onEvent(2_600))
        assertEquals(3_000, coalescer.onEvent(2_900))
    }

    @Test
    fun `fired resets the burst`() {
        val coalescer = BurstCoalescer(debounceMs = 750, maxWaitMs = 3_000)
        coalescer.onEvent(0)
        coalescer.fired()
        // Without the reset the old ceiling would still cap this at 3000.
        assertEquals(5_750, coalescer.onEvent(5_000))
    }

    @Test
    fun `the audio constants outlast the slowest observed hdmi flap`() {
        // The route was reported removed and then added 3.22 s apart on a
        // Fire TV at stop. The removal fires last, after the sink is back.
        val coalescer = BurstCoalescer(debounceMs = 4_000, maxWaitMs = 12_000)
        assertEquals(4_000, coalescer.onEvent(0))
        assertTrue(coalescer.onEvent(3_220) > 3_220)
    }

    @Test
    fun `the display constants reproduce the old schedule`() {
        val coalescer = BurstCoalescer(debounceMs = 750, maxWaitMs = 3_000)
        assertEquals(750, coalescer.onEvent(0))
        assertEquals(1_450, coalescer.onEvent(700))
        assertEquals(3_000, coalescer.onEvent(2_400))
        coalescer.fired()
        assertEquals(10_750, coalescer.onEvent(10_000))
    }
}
