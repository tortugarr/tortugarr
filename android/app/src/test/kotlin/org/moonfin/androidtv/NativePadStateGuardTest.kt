package org.moonfin.androidtv

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativePadStateGuardTest {
    @Test
    fun `keyboard state remains current without a padStates entry`() {
        val keyboardState = Any()

        assertTrue(NativePadStateGuard.isCurrent(keyboardState, keyboardState, null))
    }

    @Test
    fun `removed controller state is no longer current`() {
        val state = Any()

        assertFalse(NativePadStateGuard.isCurrent(state, Any(), null))
    }
}
