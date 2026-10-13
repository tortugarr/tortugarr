package org.moonfin.androidtv

/**
 * Session-local ownership of the four libretro controller ports. Android-free
 * so ordering and reconnect behaviour are unit testable without an emulator.
 *
 * libretro port N is in-core player N + 1; only Dart and the UI speak in
 * player numbers.
 *
 * Governing invariant: **a device holding a port never changes port except by
 * user action.** Ports are recomputed only in [activate]; mid-session a
 * connect fills a vacancy but never rearranges anyone.
 */
internal data class NativeControllerCandidate(
    val deviceId: Int,
    val profileId: String,
    val name: String,
    val controllerNumber: Int,
    val deviceClass: NativeInputDeviceClass,
)

internal data class NativeControllerConnection(
    val deviceId: Int,
    val profileId: String,
    val name: String,
    val port: Int?,
    internal val controllerNumber: Int,
    val deviceClass: NativeInputDeviceClass,
    val pinned: Boolean = false,
) {
    val connectionId: String get() = "android-connection-$deviceId"
    val supported: Boolean get() = port != null
    val isGamepad: Boolean get() = deviceClass == NativeInputDeviceClass.GAMEPAD

    /**
     * Whether the user may give this device a player slot. A keyboard is
     * assignable but is never auto-assigned; a remote is neither.
     */
    val assignable: Boolean get() = deviceClass != NativeInputDeviceClass.REMOTE

    fun channelPayload(): Map<String, Any?> = mapOf(
        "id" to profileId,
        "connectionId" to connectionId,
        "name" to name,
        "port" to port,
        "supported" to supported,
        "deviceClass" to deviceClass.name.lowercase(),
        "assignable" to assignable,
        "pinned" to pinned,
    )
}

internal class NativeControllerPortRegistry {
    private val connections = LinkedHashMap<Int, NativeControllerConnection>()

    /** Session-local reconnect memory for *unpinned* pads only. */
    private val profilePortHints = HashMap<String, Int>()

    /** Durable user assignment: profile id -> port. Supplied from Dart. */
    private var pins: Map<String, Int> = emptyMap()

    private var sessionActive = false

    /** Applies the user's durable player assignment, reallocating immediately mid-session. */
    fun setPins(next: Map<String, Int>): List<NativeControllerConnection> {
        pins = next.filterValues { it in 0 until MAX_PORTS }
        if (!sessionActive) return snapshot()
        return allocate(connections.values.map { it.toCandidate() })
    }

    fun activate(candidates: Collection<NativeControllerCandidate>): List<NativeControllerConnection> {
        sessionActive = true
        profilePortHints.clear()
        return allocate(candidates)
    }

    fun deactivate(candidates: Collection<NativeControllerCandidate>): List<NativeControllerConnection> {
        sessionActive = false
        connections.clear()
        profilePortHints.clear()
        for (candidate in candidates) {
            connections[candidate.deviceId] = candidate.toConnection(null)
        }
        return snapshot()
    }

    /** Replaces the inactive discovery snapshot without assigning gameplay ports. */
    fun refreshInactive(candidates: Collection<NativeControllerCandidate>): List<NativeControllerConnection> {
        if (sessionActive) return snapshot()
        connections.clear()
        for (candidate in candidates) {
            connections[candidate.deviceId] = candidate.toConnection(null)
        }
        return snapshot()
    }

    /**
     * Updates one live connection without moving any existing player. A new
     * device takes its pinned port, then its earlier session port, then the
     * lowest free port; a device beyond the fourth stays unsupported.
     */
    fun addOrUpdate(candidate: NativeControllerCandidate): NativeControllerConnection {
        val existing = connections[candidate.deviceId]
        if (existing != null) {
            val reclassified = existing.profileId != candidate.profileId ||
                existing.deviceClass != candidate.deviceClass
            // A device that re-enumerates as something else has no claim on the
            // port its previous identity held, and may have a pin of its own.
            // Removing first lets allocatePort see the vacated port as free;
            // every other live player keeps its port either way.
            val port = if (!reclassified) {
                existing.port
            } else {
                connections.remove(candidate.deviceId)
                if (sessionActive && isEligible(candidate)) allocatePort(candidate.profileId) else null
            }
            val updated = candidate.toConnection(port)
            connections[candidate.deviceId] = updated
            if (updated.port != null && !updated.pinned) {
                profilePortHints[candidate.profileId] = updated.port
            }
            return updated
        }

        val port = if (sessionActive && isEligible(candidate)) allocatePort(candidate.profileId) else null
        val connection = candidate.toConnection(port)
        connections[candidate.deviceId] = connection
        if (port != null && !connection.pinned) profilePortHints[candidate.profileId] = port
        return connection
    }

    /**
     * Drops a device without moving anyone else. Its port is not reserved: a pad
     * plugged in afterwards may take it, and the departed pad then gets the
     * lowest free port when it returns. Live players never move, which matters
     * more mid-game than a pad keeping its number across a sleep.
     */
    fun remove(deviceId: Int): NativeControllerConnection? = connections.remove(deviceId)

    fun connection(deviceId: Int): NativeControllerConnection? = connections[deviceId]

    fun snapshot(): List<NativeControllerConnection> = connections.values.sortedWith(
        compareBy<NativeControllerConnection>({ it.port ?: Int.MAX_VALUE }, { it.name }, { it.deviceId }),
    )

    fun assignedCount(): Int = connections.values.count { it.supported }

    /** Portless remote/keyboard connections -- the devices that feed the composed Player 1 navigation source. */
    fun navigationSourceCount(): Int = connections.values.count { !it.supported && !it.isGamepad }

    /** Session-start allocation. Pins first, then unpinned pads fill the lowest free ports. */
    private fun allocate(
        candidates: Collection<NativeControllerCandidate>,
    ): List<NativeControllerConnection> {
        val slots = arrayOfNulls<NativeControllerCandidate>(MAX_PORTS)
        val placed = HashSet<Int>()
        val eligible = candidates.filter(::isEligible)

        // Pass 1 -- pins. Identical controllers can share a profile id; the
        // lowest deviceId wins, arbitrary but stable for the session.
        for (slot in 0 until MAX_PORTS) {
            val profileId = pins.entries.firstOrNull { it.value == slot }?.key ?: continue
            val match = eligible
                .filter { it.profileId == profileId && it.deviceId !in placed }
                .minByOrNull { it.deviceId }
                ?: continue
            slots[slot] = match
            placed += match.deviceId
        }

        // Pass 2 -- fill the lowest free ports in discovery order.
        for (candidate in eligible.filterNot { it.deviceId in placed }.sortedWith(DISCOVERY_ORDER)) {
            val slot = slots.indexOfFirst { it == null }.takeIf { it >= 0 } ?: break
            slots[slot] = candidate
            placed += candidate.deviceId
        }

        val portByDeviceId = HashMap<Int, Int>()
        for ((slot, candidate) in slots.withIndex()) {
            if (candidate != null) portByDeviceId[candidate.deviceId] = slot
        }

        connections.clear()
        profilePortHints.clear()
        for (candidate in candidates) {
            val port = portByDeviceId[candidate.deviceId]
            val connection = candidate.toConnection(port)
            connections[candidate.deviceId] = connection
            if (port != null && !connection.pinned) profilePortHints[candidate.profileId] = port
        }
        return snapshot()
    }

    /** A gamepad always competes for a port; a keyboard only when pinned; a remote never. */
    private fun isEligible(candidate: NativeControllerCandidate): Boolean = when (candidate.deviceClass) {
        NativeInputDeviceClass.GAMEPAD -> true
        NativeInputDeviceClass.KEYBOARD -> pins.containsKey(candidate.profileId)
        NativeInputDeviceClass.REMOTE -> false
    }

    private fun allocatePort(profileId: String): Int? {
        val used = BooleanArray(MAX_PORTS)
        for (connection in connections.values) connection.port?.let { used[it] = true }
        val pinned = pins[profileId]
        if (pinned != null && !used[pinned]) return pinned
        val hint = profilePortHints[profileId]
        if (hint != null && !used[hint]) return hint
        return (0 until MAX_PORTS).firstOrNull { !used[it] }
    }

    private fun NativeControllerCandidate.toConnection(port: Int?): NativeControllerConnection =
        NativeControllerConnection(
            deviceId = deviceId,
            profileId = profileId,
            name = name,
            port = port,
            controllerNumber = controllerNumber,
            deviceClass = deviceClass,
            // Pinned means sitting in the user-chosen port, not merely holding
            // a different port through lowest-free allocation.
            pinned = port != null && pins[profileId] == port,
        )

    private fun NativeControllerConnection.toCandidate(): NativeControllerCandidate =
        NativeControllerCandidate(deviceId, profileId, name, controllerNumber, deviceClass)

    companion object {
        const val MAX_PORTS = 4

        private val DISCOVERY_ORDER = compareBy<NativeControllerCandidate>(
            { if (it.controllerNumber > 0) 0 else 1 },
            { if (it.controllerNumber > 0) it.controllerNumber else Int.MAX_VALUE },
            { it.deviceId },
        )
    }
}

/** Fixed, allocation-free composition of one physical source per port plus P1 keyboard/remote input. */
internal class NativePortMaskComposer {
    private val controllerMasks = IntArray(NativeControllerPortRegistry.MAX_PORTS)
    private var keyboardMask = 0

    fun setController(port: Int, mask: Int): Int {
        require(port in controllerMasks.indices)
        controllerMasks[port] = mask
        return combined(port)
    }

    fun setKeyboard(mask: Int): Int {
        keyboardMask = mask
        return combined(0)
    }

    fun combined(port: Int): Int {
        require(port in controllerMasks.indices)
        return controllerMasks[port] or if (port == 0) keyboardMask else 0
    }

    fun reset() {
        controllerMasks.fill(0)
        keyboardMask = 0
    }
}
