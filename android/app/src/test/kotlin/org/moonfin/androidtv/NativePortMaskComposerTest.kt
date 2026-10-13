package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Test

class NativePortMaskComposerTest {
    @Test
    fun `port masks remain independent and clear locally`() {
        val masks = NativePortMaskComposer()

        assertEquals(0x11, masks.setController(0, 0x11))
        assertEquals(0x22, masks.setController(1, 0x22))
        assertEquals(0x11, masks.combined(0))
        assertEquals(0, masks.setController(1, 0))
        assertEquals(0x11, masks.combined(0))
    }

    @Test
    fun `keyboard input composes only with player one`() {
        val masks = NativePortMaskComposer()

        masks.setController(0, 0x01)
        masks.setController(1, 0x02)

        assertEquals(0x05, masks.setKeyboard(0x04))
        assertEquals(0x02, masks.combined(1))
    }
}
