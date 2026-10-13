package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Test

class StickAxisDirectionTest {
    @Test
    fun `a centred stick reports nothing`() {
        assertEquals(0, stickAxisDirection(0f, 0))
    }

    @Test
    fun `the first half of the travel is no longer dead`() {
        // The old single 0.5 threshold ignored this; half the stick did nothing.
        assertEquals(1, stickAxisDirection(0.45f, 0))
        assertEquals(-1, stickAxisDirection(-0.45f, 0))
    }

    @Test
    fun `a small deflection still does not engage`() {
        assertEquals(0, stickAxisDirection(0.35f, 0))
        assertEquals(0, stickAxisDirection(-0.35f, 0))
    }

    @Test
    fun `a held direction survives drifting back below the engage point`() {
        // The chatter case: a hand resting near the trip point must not strobe
        // the direction on and off.
        assertEquals(1, stickAxisDirection(0.3f, 1))
        assertEquals(1, stickAxisDirection(0.21f, 1))
        assertEquals(-1, stickAxisDirection(-0.3f, -1))
    }

    @Test
    fun `a held direction releases once the axis falls back far enough`() {
        assertEquals(0, stickAxisDirection(0.19f, 1))
        assertEquals(0, stickAxisDirection(-0.19f, -1))
        assertEquals(0, stickAxisDirection(0f, 1))
    }

    @Test
    fun `hysteresis never holds the opposite direction`() {
        // Crossing centre must flip cleanly rather than latching the old side.
        assertEquals(-1, stickAxisDirection(-0.45f, 1))
        assertEquals(1, stickAxisDirection(0.45f, -1))
    }

    @Test
    fun `release point sits below engage point`() {
        // Guards the constants themselves: inverting these would turn the
        // Schmitt trigger back into a single trip point.
        assert(STICK_RELEASE < STICK_ENGAGE)
    }
}

class HatFallbackTest {
    @Test
    fun `a held hat always wins`() {
        assertEquals(1, hatFallback(hatDirection = 1, stickDirection = -1, coreReadsAnalog = false))
        assertEquals(1, hatFallback(hatDirection = 1, stickDirection = -1, coreReadsAnalog = true))
    }

    @Test
    fun `the stick supplies the direction while it still drives digital`() {
        assertEquals(-1, hatFallback(hatDirection = 0, stickDirection = -1, coreReadsAnalog = false))
    }

    @Test
    fun `a latched stick direction cannot leak through once the core reads analog`() {
        // The bug this guards: stickDir stops being updated when the core reads
        // analog, so returning it here pinned whatever direction was held at
        // the moment the rule engaged -- unclearable, and fighting every new
        // input (BurgerTime: could not turn to climb a ladder).
        assertEquals(0, hatFallback(hatDirection = 0, stickDirection = 1, coreReadsAnalog = true))
        assertEquals(0, hatFallback(hatDirection = 0, stickDirection = -1, coreReadsAnalog = true))
    }

    @Test
    fun `centred hat and centred stick is centred`() {
        assertEquals(0, hatFallback(hatDirection = 0, stickDirection = 0, coreReadsAnalog = false))
    }
}
