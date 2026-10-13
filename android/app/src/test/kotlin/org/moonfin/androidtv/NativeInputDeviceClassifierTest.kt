package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NativeInputDeviceClassifierTest {
    @Test
    fun `an android tv remote reporting a single face button is not a gamepad`() {
        // The onn 4K remote shape: the old rule accepted any device reporting
        // *any* of A/B/X/Y, and remotes commonly report BUTTON_A for select.
        val traits = traits(
            isExternal = true,
            hasGamepadSource = true,
            hasKeyboardSource = true,
            hasDpadSource = true,
            hasAllFaceButtons = false,
            hasDpadKeys = true,
        )

        assertEquals(NativeInputDeviceClass.REMOTE, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a pad with joystick axes is a gamepad`() {
        val traits = traits(
            isExternal = true,
            hasGamepadSource = true,
            hasJoystickSource = true,
            hasJoystickAxis = true,
        )

        assertEquals(NativeInputDeviceClass.GAMEPAD, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a pad with no axes qualifies on the full face button set`() {
        val traits = traits(
            isExternal = true,
            hasGamepadSource = true,
            hasAllFaceButtons = true,
        )

        assertEquals(NativeInputDeviceClass.GAMEPAD, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `the virtual-search pseudo device is not a gamepad`() {
        // Observed on a Shield: took Player 3 as a false GAMEPAD before this
        // guard. All-four-face-buttons alone isn't enough; isExternal excludes it.
        val traits = traits(
            isExternal = false,
            hasGamepadSource = true,
            hasKeyboardSource = true,
            hasDpadSource = true,
            hasAllFaceButtons = true,
            hasDpadKeys = true,
        )

        assertNull(NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a gpio key block is not offered as a remote`() {
        // Observed on a Shield: a board-level power/volume key block with a
        // keyboard source but no navigation keys.
        val traits = traits(
            isExternal = false,
            hasKeyboardSource = true,
            hasDpadKeys = false,
        )

        assertNull(NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `an external device that cannot navigate is not a remote`() {
        val traits = traits(
            isExternal = true,
            hasKeyboardSource = true,
            hasDpadKeys = false,
        )

        assertNull(NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `an internal pad with real sticks is still a gamepad`() {
        // The joystick-axis rule runs before the external check, so it's unaffected.
        val traits = traits(
            isExternal = false,
            hasGamepadSource = true,
            hasJoystickAxis = true,
        )

        assertEquals(NativeInputDeviceClass.GAMEPAD, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `an alphabetic keyboard is a keyboard`() {
        val traits = traits(
            isExternal = true,
            hasKeyboardSource = true,
            isAlphabeticKeyboard = true,
        )

        assertEquals(NativeInputDeviceClass.KEYBOARD, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a non alphabetic keyboard source is a remote`() {
        val traits = traits(
            isExternal = true,
            hasKeyboardSource = true,
            hasDpadKeys = true,
            isAlphabeticKeyboard = false,
        )

        assertEquals(NativeInputDeviceClass.REMOTE, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a touch navigation surface is a remote`() {
        val traits = traits(
            isExternal = true,
            hasTouchNavigationSource = true,
            hasDpadKeys = true,
        )

        assertEquals(NativeInputDeviceClass.REMOTE, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a keyboard that also reports every face button is treated as a gamepad`() {
        // Gamepad rules run before the keyboard rule, so this isn't demoted.
        val traits = traits(
            isExternal = true,
            hasGamepadSource = true,
            hasKeyboardSource = true,
            hasAllFaceButtons = true,
            isAlphabeticKeyboard = true,
        )

        assertEquals(NativeInputDeviceClass.GAMEPAD, NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a virtual device is ignored`() {
        val traits = traits(isVirtual = true, hasJoystickAxis = true, hasGamepadSource = true)

        assertNull(NativeInputDeviceClassifier.classify(traits))
    }

    @Test
    fun `a gamepad source with no other evidence is ignored`() {
        // Unidentifiable, so routed nowhere rather than guessed into a class.
        val traits = traits(hasGamepadSource = true)

        assertNull(NativeInputDeviceClassifier.classify(traits))
    }

    private fun traits(
        isVirtual: Boolean = false,
        isExternal: Boolean = false,
        hasGamepadSource: Boolean = false,
        hasJoystickSource: Boolean = false,
        hasKeyboardSource: Boolean = false,
        hasDpadSource: Boolean = false,
        hasTouchNavigationSource: Boolean = false,
        hasJoystickAxis: Boolean = false,
        hasAllFaceButtons: Boolean = false,
        hasDpadKeys: Boolean = false,
        isAlphabeticKeyboard: Boolean = false,
    ) = NativeInputDeviceTraits(
        isVirtual = isVirtual,
        isExternal = isExternal,
        hasGamepadSource = hasGamepadSource,
        hasJoystickSource = hasJoystickSource,
        hasKeyboardSource = hasKeyboardSource,
        hasDpadSource = hasDpadSource,
        hasTouchNavigationSource = hasTouchNavigationSource,
        hasJoystickAxis = hasJoystickAxis,
        hasAllFaceButtons = hasAllFaceButtons,
        hasDpadKeys = hasDpadKeys,
        isAlphabeticKeyboard = isAlphabeticKeyboard,
    )
}
