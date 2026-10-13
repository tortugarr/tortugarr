package org.moonfin.androidtv

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Test

class NativeMappingTablesTest {
    @Test
    fun `default table maps the d-pad and confirm keys`() {
        val table = NativeMappingTables.DEFAULT
        assertEquals(NativeMappingTables.RETRO_UP, table[KeyEvent.KEYCODE_DPAD_UP])
        assertEquals(NativeMappingTables.RETRO_DOWN, table[KeyEvent.KEYCODE_DPAD_DOWN])
        assertEquals(NativeMappingTables.RETRO_LEFT, table[KeyEvent.KEYCODE_DPAD_LEFT])
        assertEquals(NativeMappingTables.RETRO_RIGHT, table[KeyEvent.KEYCODE_DPAD_RIGHT])
        assertEquals(NativeMappingTables.RETRO_A, table[KeyEvent.KEYCODE_DPAD_CENTER])
        assertEquals(NativeMappingTables.RETRO_A, table[KeyEvent.KEYCODE_ENTER])
    }

    @Test
    fun `back, home and volume keys are never bound or swallowed`() {
        val table = NativeMappingTables.DEFAULT
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_BACK])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_HOME])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_VOLUME_UP])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_VOLUME_DOWN])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_VOLUME_MUTE])
    }

    @Test
    fun `media keys are swallowed by default`() {
        val table = NativeMappingTables.DEFAULT
        assertEquals(NativeMappingTables.SWALLOW, table[KeyEvent.KEYCODE_MEDIA_FAST_FORWARD])
        assertEquals(NativeMappingTables.SWALLOW, table[KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE])
    }

    @Test
    fun `a user binding overrides the swallow entry`() {
        val table = NativeMappingTables.custom(
            mapOf(KeyEvent.KEYCODE_MEDIA_FAST_FORWARD to NativeMappingTables.RETRO_L1),
        )
        assertEquals(NativeMappingTables.RETRO_L1, table[KeyEvent.KEYCODE_MEDIA_FAST_FORWARD])
    }

    @Test
    fun `null overrides return the default table identically`() {
        val table = NativeMappingTables.custom(null)
        assertEquals(NativeMappingTables.DEFAULT.toList(), table.toList())
    }

    @Test
    fun `custom never mutates the default table`() {
        NativeMappingTables.custom(mapOf(KeyEvent.KEYCODE_MEDIA_FAST_FORWARD to NativeMappingTables.RETRO_L1))
        assertEquals(NativeMappingTables.SWALLOW, NativeMappingTables.DEFAULT[KeyEvent.KEYCODE_MEDIA_FAST_FORWARD])

        NativeMappingTables.custom(mapOf(KeyEvent.KEYCODE_DPAD_UP to NativeMappingTables.RETRO_B))
        assertEquals(NativeMappingTables.RETRO_UP, NativeMappingTables.DEFAULT[KeyEvent.KEYCODE_DPAD_UP])
    }

    @Test
    fun `out-of-range keycodes and indices in overrides are ignored`() {
        val table = NativeMappingTables.custom(
            mapOf(
                -1 to NativeMappingTables.RETRO_A,
                NativeMappingTables.TABLE_SIZE to NativeMappingTables.RETRO_A,
                KeyEvent.KEYCODE_DPAD_UP to -1,
                KeyEvent.KEYCODE_DPAD_DOWN to 16,
            ),
        )
        assertEquals(NativeMappingTables.RETRO_UP, table[KeyEvent.KEYCODE_DPAD_UP])
        assertEquals(NativeMappingTables.RETRO_DOWN, table[KeyEvent.KEYCODE_DPAD_DOWN])
    }

    @Test
    fun `indexFor returns NONE outside the table's range`() {
        val table = NativeMappingTables.DEFAULT
        assertEquals(NativeMappingTables.NONE, NativeMappingTables.indexFor(table, NativeMappingTables.TABLE_SIZE))
        assertEquals(NativeMappingTables.NONE, NativeMappingTables.indexFor(table, -1))
    }

    @Test
    fun `an unbound trigger keeps the default L2 and R2 bits`() {
        val table = NativeMappingTables.custom(null)
        assertEquals(NativeMappingTables.RETRO_L2, table[KeyEvent.KEYCODE_BUTTON_L2])
        assertEquals(NativeMappingTables.RETRO_R2, table[KeyEvent.KEYCODE_BUTTON_R2])
    }

    @Test
    fun `a rebound trigger resolves to the chosen button`() {
        val table = NativeMappingTables.custom(
            mapOf(KeyEvent.KEYCODE_BUTTON_L2 to NativeMappingTables.RETRO_A),
        )
        assertEquals(NativeMappingTables.RETRO_A, NativeMappingTables.indexFor(table, KeyEvent.KEYCODE_BUTTON_L2))
        assertEquals(NativeMappingTables.RETRO_R2, NativeMappingTables.indexFor(table, KeyEvent.KEYCODE_BUTTON_R2))
    }

    @Test
    fun `trigger bindings saved under the old synthetic codes still load`() {
        val table = NativeMappingTables.custom(
            mapOf(
                NativeMappingTables.SYNTHETIC_KEYCODE_L2 to NativeMappingTables.RETRO_A,
                NativeMappingTables.SYNTHETIC_KEYCODE_R2 to NativeMappingTables.RETRO_B,
            ),
        )
        assertEquals(NativeMappingTables.RETRO_A, table[KeyEvent.KEYCODE_BUTTON_L2])
        assertEquals(NativeMappingTables.RETRO_B, table[KeyEvent.KEYCODE_BUTTON_R2])
    }

    @Test
    fun `binding a key to a button unbinds the default that used to drive it`() {
        val table = NativeMappingTables.custom(
            mapOf(KeyEvent.KEYCODE_BUTTON_L2 to NativeMappingTables.RETRO_A),
        )
        assertEquals(NativeMappingTables.RETRO_A, table[KeyEvent.KEYCODE_BUTTON_L2])
        // RETRO_A is the only index with several defaults; every one of them goes,
        // or the old key would keep firing alongside the new one.
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_BUTTON_A])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_DPAD_CENTER])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_ENTER])
        // Untouched buttons keep their defaults.
        assertEquals(NativeMappingTables.RETRO_B, table[KeyEvent.KEYCODE_BUTTON_B])
    }

    @Test
    fun `a key bound to a new button keeps its own entry and frees the old one`() {
        val table = NativeMappingTables.custom(
            mapOf(KeyEvent.KEYCODE_BUTTON_A to NativeMappingTables.RETRO_Y),
        )
        assertEquals(NativeMappingTables.RETRO_Y, table[KeyEvent.KEYCODE_BUTTON_A])
        assertEquals(NativeMappingTables.NONE, table[KeyEvent.KEYCODE_BUTTON_Y])
    }

    @Test
    fun `an unbound layout is unaffected by the exclusivity pass`() {
        assertEquals(NativeMappingTables.RETRO_A, NativeMappingTables.custom(null)[KeyEvent.KEYCODE_BUTTON_A])
        val table = NativeMappingTables.custom(emptyMap())
        assertEquals(NativeMappingTables.RETRO_A, table[KeyEvent.KEYCODE_DPAD_CENTER])
        assertEquals(NativeMappingTables.RETRO_L2, table[KeyEvent.KEYCODE_BUTTON_L2])
    }
}
