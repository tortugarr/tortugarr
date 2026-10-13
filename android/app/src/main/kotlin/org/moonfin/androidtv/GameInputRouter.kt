package org.moonfin.androidtv

import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent

/**
 * Owns Android input policy for the EmulatorJS (WebView) path only, translating
 * Android events to EmulatorJS's upstream labels. The native libretro path is
 * owned by [NativePadInput], checked first in [MainActivity.dispatchKeyEvent]
 * so nothing gameplay-shaped reaches here during a native session.
 */
internal class GameInputRouter(
    private val callbacks: Callbacks,
) {
    internal interface Callbacks {
        fun onEmulatorButton(label: String, pressed: Boolean, device: Map<String, String>?)
        fun onEmulatorKeyboard(keyCode: Int)
        fun onNavigate(axis: String, direction: String)
    }

    private var gameActive = false
    private var emulatorControlsActive = false
    // Off until Dart says otherwise, matching the preference default, so a pad
    // can't drive the UI in the moments before the flag arrives.
    private var navigationEnabled = false
    // Per controller, not global.
    private class PadState {
        var hatX = 0
        var hatY = 0
        var motionDpadX = 0
        var motionDpadY = 0
        val pressedDpadKeys = mutableSetOf<Int>()
        var leftTriggerPressed = false
        var rightTriggerPressed = false

        // Every label currently reported pressed, so a disconnect can release
        // face/shoulder/Start/Select too rather than only directions.
        val heldLabels = mutableSetOf<String>()

        // The identity those presses were emitted with. Held here rather than
        // read from deviceCache at release time, which onDeviceChanged can
        // invalidate while labels are still held.
        var identity: Map<String, String>? = null
    }

    private val padStates = mutableMapOf<String, PadState>()

    // A removed device can no longer be resolved with InputDevice.getDevice, so
    // its descriptor has to be remembered while it is still present.
    private val descriptorsByDeviceId = mutableMapOf<Int, String>()

    private fun descriptorOf(device: InputDevice?): String {
        val descriptor = device?.descriptor ?: return UNKNOWN_DEVICE_KEY
        descriptorsByDeviceId[device.id] = descriptor
        return descriptor
    }

    private fun padState(device: InputDevice?): PadState =
        padStates.getOrPut(descriptorOf(device)) { PadState() }
    private var navX = 0
    private var navY = 0

    // Device IDs can change after reconnecting; cache identity by descriptor
    // for the active session only.
    private val deviceCache = mutableMapOf<String, Map<String, String>>()

    fun setGameActive(active: Boolean) {
        gameActive = active
        resetSessionState()
    }

    fun setEmulatorControlsActive(active: Boolean) {
        emulatorControlsActive = active
    }

    fun setNavigationEnabled(enabled: Boolean) {
        navigationEnabled = enabled
        // Stick moves go untracked while off, so the first one after turning
        // back on has to read as a change.
        navX = 0
        navY = 0
    }

    /**
     * True when this key is a pad button driving the UI while the user has
     * turned that off. Only the codes Android reserves for pad buttons count,
     * so a remote can't be caught by it whatever it reports itself as, and a
     * pad's d-pad keeps working like any other d-pad. Only outside a game: a
     * running game owns its pad, and what it lets fall through still has to
     * reach Android.
     */
    fun blocksNavigation(event: KeyEvent): Boolean =
        !gameActive && !navigationEnabled && KeyEvent.isGamepadButton(event.keyCode)

    fun gamepadDevices(): List<Map<String, String>> =
        InputDevice.getDeviceIds()
            .asIterable()
            .mapNotNull { InputDevice.getDevice(it) }
            .filter(::isPhysicalGamepad)
            .map(::deviceIdentity)

    /** Returns true only when this router consumed the event. */
    fun onKeyEvent(event: KeyEvent): Boolean {
        if (!gameActive) return false

        val device = physicalDevice(event.device)
        if (handlePhysicalDpadKey(event, device)) return true
        val label = emulatorGamepadLabel(event.keyCode)
        if (label != null) {
            // Let Android's normal back handling operate outside the emulator controls.
            if (label == BACK && !emulatorControlsActive) return false

            val isRemoteNavigationRepeat =
                emulatorControlsActive &&
                    device == null &&
                    label in DPAD_LABELS &&
                    event.action == KeyEvent.ACTION_DOWN
            if ((event.repeatCount == 0 || isRemoteNavigationRepeat) && isButtonTransition(event)) {
                emitButton(label, event.action == KeyEvent.ACTION_DOWN, device)
            }
            return true
        }

        if (emulatorControlsActive &&
            event.action == KeyEvent.ACTION_DOWN &&
            event.repeatCount == 0
        ) {
            domKeyCode(event.keyCode)?.let {
                callbacks.onEmulatorKeyboard(it)
                return true
            }
        }
        return false
    }

    /** Returns true when gameplay motion was consumed. */
    fun onMotionEvent(event: MotionEvent): Boolean {
        if (gameActive && isJoystickMove(event)) {
            val device = event.device
            val state = padState(device)
            state.motionDpadX = axisDirection(event, MotionEvent.AXIS_HAT_X, MotionEvent.AXIS_X)
            state.motionDpadY = axisDirection(event, MotionEvent.AXIS_HAT_Y, MotionEvent.AXIS_Y)
            updateGameplayDpad(state, device)

            updateTrigger(event, MotionEvent.AXIS_LTRIGGER, LEFT_BOTTOM_SHOULDER, state.leftTriggerPressed) {
                state.leftTriggerPressed = it
            }
            updateTrigger(event, MotionEvent.AXIS_RTRIGGER, RIGHT_BOTTOM_SHOULDER, state.rightTriggerPressed) {
                state.rightTriggerPressed = it
            }
            return true
        }

        // Outside a game the left stick drives UI focus. Ignore the HAT here:
        // Android already exposes its d-pad as keys, and double delivery can
        // cause one path to release the other's held direction.
        if (!gameActive && navigationEnabled && isJoystickMove(event)) {
            updateNavigation("h", stickDirection(event, MotionEvent.AXIS_X), navX) { navX = it }
            updateNavigation("v", stickDirection(event, MotionEvent.AXIS_Y), navY) { navY = it }
        }
        return false
    }

    /**
     * A device that vanishes mid-press sends no release, so EmulatorJS would
     * hold it for ever -- and the stale state would then swallow the next press
     * after a reconnect under the same descriptor.
     */
    fun onDeviceRemoved(deviceId: Int) {
        val descriptor = descriptorsByDeviceId.remove(deviceId) ?: return
        padStates.remove(descriptor)?.let { state ->
            for (label in state.heldLabels) {
                callbacks.onEmulatorButton(label, false, state.identity)
            }
        }
        deviceCache.remove(descriptor)
        NativeInputDeviceClassifier.invalidate(deviceId)
    }

    /** Capabilities and identity may both have changed. */
    fun onDeviceChanged(deviceId: Int) {
        val descriptor = descriptorsByDeviceId[deviceId] ?: return
        deviceCache.remove(descriptor)
        NativeInputDeviceClassifier.invalidate(deviceId)
    }

    private fun resetSessionState() {
        padStates.clear()
        descriptorsByDeviceId.clear()
        navX = 0
        navY = 0
        deviceCache.clear()
        NativeInputDeviceClassifier.invalidate()
    }

    // Single emit path, so heldLabels always matches what EmulatorJS believes
    // is pressed.
    private fun emitButton(label: String, pressed: Boolean, device: InputDevice?) {
        val identity = device?.let(::deviceIdentity)
        if (device != null) {
            val state = padState(device)
            if (pressed) state.heldLabels += label else state.heldLabels -= label
            state.identity = identity
        }
        callbacks.onEmulatorButton(label, pressed, identity)
    }

    private fun emitEmulatorAxisTransition(
        previous: Int,
        next: Int,
        negative: String,
        positive: String,
        device: InputDevice?,
    ) {
        val physical = physicalDevice(device)
        if (previous == -1) emitButton(negative, false, physical)
        if (previous == 1) emitButton(positive, false, physical)
        if (next == -1) emitButton(negative, true, physical)
        if (next == 1) emitButton(positive, true, physical)
    }

    /** Returns true when this key was a D-pad transition this method fully handled. */
    private fun handlePhysicalDpadKey(event: KeyEvent, device: InputDevice?): Boolean {
        if (device == null || event.repeatCount != 0 || !isButtonTransition(event)) return false
        if (event.keyCode !in DPAD_KEY_CODES) return false
        val state = padState(device)
        if (event.action == KeyEvent.ACTION_DOWN) {
            state.pressedDpadKeys += event.keyCode
        } else {
            state.pressedDpadKeys -= event.keyCode
        }
        updateGameplayDpad(state, device)
        return true
    }

    private fun updateGameplayDpad(state: PadState, device: InputDevice?) {
        val keyX = when {
            KeyEvent.KEYCODE_DPAD_LEFT in state.pressedDpadKeys -> -1
            KeyEvent.KEYCODE_DPAD_RIGHT in state.pressedDpadKeys -> 1
            else -> 0
        }
        val keyY = when {
            KeyEvent.KEYCODE_DPAD_UP in state.pressedDpadKeys -> -1
            KeyEvent.KEYCODE_DPAD_DOWN in state.pressedDpadKeys -> 1
            else -> 0
        }
        val nextX = keyX.takeIf { it != 0 } ?: state.motionDpadX
        val nextY = keyY.takeIf { it != 0 } ?: state.motionDpadY
        if (nextX != state.hatX) {
            emitEmulatorAxisTransition(state.hatX, nextX, "DPAD_LEFT", "DPAD_RIGHT", device)
            state.hatX = nextX
        }
        if (nextY != state.hatY) {
            emitEmulatorAxisTransition(state.hatY, nextY, "DPAD_UP", "DPAD_DOWN", device)
            state.hatY = nextY
        }
    }

    private fun updateTrigger(
        event: MotionEvent,
        axis: Int,
        label: String,
        previous: Boolean,
        setPressed: (Boolean) -> Unit,
    ) {
        val pressed = event.getAxisValue(axis) >= AXIS_PRESS_THRESHOLD
        if (pressed != previous) {
            emitButton(label, pressed, physicalDevice(event.device))
            setPressed(pressed)
        }
    }

    private fun updateNavigation(axis: String, next: Int, previous: Int, setDirection: (Int) -> Unit) {
        if (next != previous) {
            setDirection(next)
            callbacks.onNavigate(
                axis,
                when (next) {
                    -1 -> if (axis == "h") "left" else "up"
                    1 -> if (axis == "h") "right" else "down"
                    else -> "none"
                },
            )
        }
    }

    private fun physicalDevice(device: InputDevice?): InputDevice? =
        device?.takeIf(::isPhysicalGamepad)

    // Shares NativeInputDeviceClassifier with the native libretro path so the
    // two can't disagree on the same device. Uses classifyCached, not classify:
    // this runs per key event, and the uncached form's binder calls can block
    // the main thread long enough to trip an input-dispatch ANR.
    private fun isPhysicalGamepad(device: InputDevice): Boolean =
        NativeInputDeviceClassifier.classifyCached(device) == NativeInputDeviceClass.GAMEPAD

    private fun deviceIdentity(device: InputDevice): Map<String, String> {
        val descriptor = descriptorOf(device)
        deviceCache[descriptor]?.let { return it }
        return AndroidGamepadIdentity.of(device).also { deviceCache[descriptor] = it }
    }

    private fun isJoystickMove(event: MotionEvent): Boolean =
        event.source and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK &&
            event.action == MotionEvent.ACTION_MOVE

    private fun axisDirection(event: MotionEvent, hatAxis: Int, stickAxis: Int): Int =
        direction(event.getAxisValue(hatAxis)).takeIf { it != 0 }
            ?: direction(event.getAxisValue(stickAxis))

    private fun stickDirection(event: MotionEvent, axis: Int): Int = direction(event.getAxisValue(axis))

    private fun direction(value: Float): Int = when {
        value <= -AXIS_PRESS_THRESHOLD -> -1
        value >= AXIS_PRESS_THRESHOLD -> 1
        else -> 0
    }

    private fun isButtonTransition(event: KeyEvent): Boolean =
        event.action == KeyEvent.ACTION_DOWN || event.action == KeyEvent.ACTION_UP

    private fun emulatorGamepadLabel(keyCode: Int): String? = EMULATOR_JS_KEYS[keyCode]

    private fun domKeyCode(keyCode: Int): Int? = when (keyCode) {
        in KeyEvent.KEYCODE_A..KeyEvent.KEYCODE_Z -> 65 + keyCode - KeyEvent.KEYCODE_A
        in KeyEvent.KEYCODE_0..KeyEvent.KEYCODE_9 -> 48 + keyCode - KeyEvent.KEYCODE_0
        KeyEvent.KEYCODE_TAB -> 9
        KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> 13
        KeyEvent.KEYCODE_DEL -> 8
        KeyEvent.KEYCODE_FORWARD_DEL -> 46
        KeyEvent.KEYCODE_SPACE -> 32
        KeyEvent.KEYCODE_ESCAPE -> 27
        KeyEvent.KEYCODE_MINUS -> 189
        KeyEvent.KEYCODE_EQUALS -> 187
        KeyEvent.KEYCODE_LEFT_BRACKET -> 219
        KeyEvent.KEYCODE_RIGHT_BRACKET -> 221
        KeyEvent.KEYCODE_BACKSLASH -> 220
        KeyEvent.KEYCODE_SEMICOLON -> 186
        KeyEvent.KEYCODE_APOSTROPHE -> 222
        KeyEvent.KEYCODE_COMMA -> 188
        KeyEvent.KEYCODE_PERIOD -> 190
        KeyEvent.KEYCODE_SLASH -> 191
        KeyEvent.KEYCODE_GRAVE -> 192
        in KeyEvent.KEYCODE_F1..KeyEvent.KEYCODE_F12 -> 112 + keyCode - KeyEvent.KEYCODE_F1
        else -> null
    }

    private companion object {
        const val AXIS_PRESS_THRESHOLD = 0.5f
        // Events that arrive without an InputDevice share one bucket rather
        // than colliding with a real controller's state.
        const val UNKNOWN_DEVICE_KEY = ""
        const val BACK = "BACK"
        const val LEFT_BOTTOM_SHOULDER = "LEFT_BOTTOM_SHOULDER"
        const val RIGHT_BOTTOM_SHOULDER = "RIGHT_BOTTOM_SHOULDER"
        val DPAD_LABELS = setOf("DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT")
        val DPAD_KEY_CODES = setOf(
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
        )
        val EMULATOR_JS_KEYS = mapOf(
            KeyEvent.KEYCODE_BACK to BACK,
            KeyEvent.KEYCODE_DPAD_UP to "DPAD_UP",
            KeyEvent.KEYCODE_DPAD_DOWN to "DPAD_DOWN",
            KeyEvent.KEYCODE_DPAD_LEFT to "DPAD_LEFT",
            KeyEvent.KEYCODE_DPAD_RIGHT to "DPAD_RIGHT",
            KeyEvent.KEYCODE_DPAD_CENTER to "BUTTON_2",
            KeyEvent.KEYCODE_ENTER to "BUTTON_2",
            KeyEvent.KEYCODE_BUTTON_A to "BUTTON_2",
            KeyEvent.KEYCODE_BUTTON_B to "BUTTON_1",
            KeyEvent.KEYCODE_BUTTON_X to "BUTTON_4",
            KeyEvent.KEYCODE_BUTTON_Y to "BUTTON_0",
            KeyEvent.KEYCODE_BUTTON_START to "START",
            KeyEvent.KEYCODE_BUTTON_SELECT to "SELECT",
            KeyEvent.KEYCODE_BUTTON_L1 to "BUTTON_6",
            KeyEvent.KEYCODE_BUTTON_R1 to "BUTTON_7",
            KeyEvent.KEYCODE_BUTTON_L2 to LEFT_BOTTOM_SHOULDER,
            KeyEvent.KEYCODE_BUTTON_R2 to RIGHT_BOTTOM_SHOULDER,
            KeyEvent.KEYCODE_BUTTON_THUMBL to "BUTTON_10",
            KeyEvent.KEYCODE_BUTTON_THUMBR to "BUTTON_11",
        )
    }
}
