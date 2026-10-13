package org.moonfin.androidtv

import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent

/**
 * What kind of input device Android has handed us.
 *
 * Android exposes no "is this a remote" API, so classification is inferred
 * from advertised capabilities (keyboard type, touch-navigation source, etc.).
 */
internal enum class NativeInputDeviceClass { GAMEPAD, KEYBOARD, REMOTE }

/**
 * The capability snapshot [NativeInputDeviceClassifier] decides from. Kept free
 * of Android types so classification is unit testable without an emulator.
 */
internal data class NativeInputDeviceTraits(
    val isVirtual: Boolean,
    val isExternal: Boolean,
    val hasGamepadSource: Boolean,
    val hasJoystickSource: Boolean,
    val hasKeyboardSource: Boolean,
    val hasDpadSource: Boolean,
    val hasTouchNavigationSource: Boolean,
    val hasJoystickAxis: Boolean,
    val hasAllFaceButtons: Boolean,
    val hasDpadKeys: Boolean,
    val isAlphabeticKeyboard: Boolean,
)

internal object NativeInputDeviceClassifier {
    /** Null means the device is not an input source this app should route at all. */
    fun classify(traits: NativeInputDeviceTraits): NativeInputDeviceClass? = when {
        traits.isVirtual -> null
        traits.hasJoystickAxis -> NativeInputDeviceClass.GAMEPAD
        // Must be .all, not .any: TV remotes commonly report BUTTON_A for select.
        // isExternal is required too -- Android TV's internal virtual-search/
        // virtual-keyboard pseudo-devices declare full face-button layouts and
        // one of them took a player slot without this guard.
        (traits.hasGamepadSource || traits.hasJoystickSource) &&
            traits.isExternal &&
            traits.hasAllFaceButtons -> NativeInputDeviceClass.GAMEPAD
        traits.hasKeyboardSource && traits.isAlphabeticKeyboard && traits.isExternal ->
            NativeInputDeviceClass.KEYBOARD
        // hasDpadKeys keeps a power/volume block like gpio-keys from being
        // listed as a navigation device.
        traits.isExternal &&
            (traits.hasTouchNavigationSource || traits.hasDpadSource || traits.hasKeyboardSource) &&
            traits.hasDpadKeys -> NativeInputDeviceClass.REMOTE
        // Unclassified devices still reach Player 1 via NativePadInput's keyboard state.
        else -> null
    }

    fun classify(device: InputDevice): NativeInputDeviceClass? = classify(traitsOf(device))

    /**
     * [classify] for the per-key-event path, which must avoid binder calls:
     * `traitsOf`'s `hasKeys()` calls are synchronous round trips to
     * system_server, and paying that per key event risks an input-dispatch ANR.
     * Keyed by descriptor+deviceId, since descriptor alone isn't guaranteed
     * non-empty. A device list change evicts the device it names, and teardown
     * clears the lot.
     */
    fun classifyCached(device: InputDevice): NativeInputDeviceClass? {
        val key = "${device.descriptor}:${device.id}"
        synchronized(cache) {
            if (cache.containsKey(key)) return cache[key]
        }
        val result = classify(device)
        synchronized(cache) { cache[key] = result }
        return result
    }

    /**
     * Evicts one device. Matching on the id suffix can drop a little more than
     * asked, which only costs a recomputed classification.
     */
    fun invalidate(deviceId: Int) {
        val suffix = ":$deviceId"
        synchronized(cache) { cache.keys.removeAll { it.endsWith(suffix) } }
    }

    /** Drops the whole cache, for teardown and session resets. */
    fun invalidate() {
        synchronized(cache) { cache.clear() }
    }

    private val cache = HashMap<String, NativeInputDeviceClass?>()

    fun traitsOf(device: InputDevice): NativeInputDeviceTraits {
        val hasJoystickAxis = device.motionRanges.any { range ->
            range.source and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
        }
        return NativeInputDeviceTraits(
            isVirtual = device.isVirtual,
            isExternal = device.isExternal,
            hasGamepadSource = device.supportsSource(InputDevice.SOURCE_GAMEPAD),
            hasJoystickSource = device.supportsSource(InputDevice.SOURCE_JOYSTICK),
            hasKeyboardSource = device.supportsSource(InputDevice.SOURCE_KEYBOARD),
            hasDpadSource = device.supportsSource(InputDevice.SOURCE_DPAD),
            hasTouchNavigationSource = device.supportsSource(InputDevice.SOURCE_TOUCH_NAVIGATION),
            hasJoystickAxis = hasJoystickAxis,
            // Skip the hasKeys() binder call: an axis already settles the gamepad rule.
            hasAllFaceButtons = if (hasJoystickAxis) false else hasAllFaceButtons(device),
            // Only the remote rule consults this, so skip it too when already a pad.
            hasDpadKeys = if (hasJoystickAxis) false else hasDpadKeys(device),
            isAlphabeticKeyboard = device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC,
        )
    }

    private fun hasAllFaceButtons(device: InputDevice): Boolean = device.hasKeys(
        KeyEvent.KEYCODE_BUTTON_A,
        KeyEvent.KEYCODE_BUTTON_B,
        KeyEvent.KEYCODE_BUTTON_X,
        KeyEvent.KEYCODE_BUTTON_Y,
    ).all { it }

    private fun hasDpadKeys(device: InputDevice): Boolean = device.hasKeys(
        KeyEvent.KEYCODE_DPAD_UP,
        KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT,
        KeyEvent.KEYCODE_DPAD_RIGHT,
    ).all { it }

    /**
     * One line per device at session start, so classification is a logcat grep
     * instead of a guess. Microphone/Bluetooth fields are for identification
     * only and never affect classification (some gamepads report microphones).
     */
    fun logDiagnostics(device: InputDevice, traits: NativeInputDeviceTraits) {
        val deviceClass = classify(traits)?.name ?: "IGNORED"
        val faceButtons = if (traits.hasJoystickAxis) "skipped" else traits.hasAllFaceButtons.toString()
        val dpadKeys = if (traits.hasJoystickAxis) "skipped" else traits.hasDpadKeys.toString()
        Log.i(
            TAG,
            "device=${device.name} vendor=${device.vendorId} product=${device.productId} " +
                "sources=0x${Integer.toHexString(device.sources)} keyboardType=${device.keyboardType} " +
                "gamepad=${traits.hasGamepadSource} joystick=${traits.hasJoystickSource} " +
                "keyboard=${traits.hasKeyboardSource} dpad=${traits.hasDpadSource} " +
                "touchNav=${traits.hasTouchNavigationSource} joystickAxis=${traits.hasJoystickAxis} " +
                "allFaceButtons=$faceButtons dpadKeys=$dpadKeys " +
                "alphabetic=${traits.isAlphabeticKeyboard} " +
                "external=${traits.isExternal} mic=${device.hasMicrophone()} -> $deviceClass",
        )
    }

    private const val TAG = "moonfin_input"
}
