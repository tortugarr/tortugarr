package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeControllerPortRegistryTest {
    @Test
    fun `activation orders positive controller numbers before device id`() {
        val registry = NativeControllerPortRegistry()

        val connections = registry.activate(
            listOf(
                candidate(12, "late", controllerNumber = 2),
                candidate(2, "no-number", controllerNumber = 0),
                candidate(7, "first", controllerNumber = 1),
            ),
        )

        assertEquals(listOf("first", "late", "no-number"), connections.map { it.profileId })
        assertEquals(listOf(0, 1, 2), connections.map { it.port })
    }

    @Test
    fun `removed port is reused by a reconnecting profile`() {
        val registry = NativeControllerPortRegistry()
        registry.activate(listOf(candidate(1, "p1"), candidate(2, "p2")))

        val removed = registry.remove(2)
        val reconnect = registry.addOrUpdate(candidate(20, "p2"))

        assertEquals(1, removed?.port)
        assertEquals(1, reconnect.port)
    }

    @Test
    fun `add before old remove lets a pinned controller reclaim its port`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("p1" to 0))
        registry.activate(listOf(candidate(1, "p1"), candidate(2, "p2")))

        // NativePadInput notices that device 1 vanished while handling device
        // 20's add callback, then frees only that stale connection.
        registry.remove(1)
        val returned = registry.addOrUpdate(candidate(20, "p1"))

        assertEquals(0, returned.port)
        assertEquals(1, registry.connection(2)?.port)
    }

    @Test
    fun `late removal after a reconnect cannot remove the replacement`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("p1" to 0))
        registry.activate(listOf(candidate(1, "p1"), candidate(2, "p2")))
        registry.remove(1)
        registry.addOrUpdate(candidate(20, "p1"))

        assertNull(registry.remove(1))
        assertEquals(0, registry.connection(20)?.port)
        assertEquals(1, registry.connection(2)?.port)
    }

    @Test
    fun `fifth connection remains visible but unsupported`() {
        val registry = NativeControllerPortRegistry()
        val connections = registry.activate((1..5).map { candidate(it, "p$it") })

        assertEquals(4, registry.assignedCount())
        assertNull(connections.single { it.profileId == "p5" }.port)
        assertFalse(connections.single { it.profileId == "p5" }.supported)
    }

    @Test
    fun `a disconnect does not promote an already connected spare`() {
        val registry = NativeControllerPortRegistry()
        registry.activate((1..5).map { candidate(it, "p$it") })

        registry.remove(2)

        // No reallocation runs, so the spare stays unsupported and nobody moves.
        assertNull(registry.snapshot().single { it.profileId == "p5" }.port)
        assertTrue(registry.snapshot().none { it.port == 1 })
    }

    @Test
    fun `a pad plugged in after a disconnect keeps the vacated port when the sleeper returns`() {
        val registry = NativeControllerPortRegistry()
        registry.activate(listOf(candidate(1, "p1"), candidate(2, "p2")))
        registry.remove(1)

        val fresh = registry.addOrUpdate(candidate(7, "p7"))
        val returned = registry.addOrUpdate(candidate(1, "p1"))

        // Session stability wins: the pad now playing on port 0 is not displaced,
        // so the returning pad takes the lowest free port instead.
        assertEquals(0, fresh.port)
        assertEquals(2, returned.port)
        assertEquals(1, registry.connection(2)?.port)
    }

    @Test
    fun `a sleeping pad reclaims its own port on reconnect`() {
        val registry = NativeControllerPortRegistry()
        registry.activate((1..5).map { candidate(it, "p$it") })
        registry.remove(1)

        val returned = registry.addOrUpdate(candidate(1, "p1"))

        assertEquals(0, returned.port)
    }

    @Test
    fun `identical profiles retain distinct runtime connections`() {
        val registry = NativeControllerPortRegistry()
        val connections = registry.activate(listOf(candidate(3, "shared"), candidate(4, "shared")))

        assertEquals(listOf("shared", "shared"), connections.map { it.profileId })
        assertEquals(listOf(0, 1), connections.map { it.port })
        assertEquals(2, connections.map { it.connectionId }.toSet().size)
        assertTrue(connections.all { it.supported })
    }

    @Test
    fun `inactive snapshot exposes profiles without gameplay ports`() {
        val registry = NativeControllerPortRegistry()
        val snapshot = registry.refreshInactive(listOf(candidate(5, "profile")))

        assertNull(snapshot.single().port)
        assertFalse(snapshot.single().supported)
    }

    @Test
    fun `pins place devices on their chosen ports regardless of discovery order`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("eightbitdo" to 0, "xbox" to 1))

        val connections = registry.activate(
            listOf(
                candidate(9, "xbox", controllerNumber = 1),
                candidate(3, "eightbitdo", controllerNumber = 2),
            ),
        )

        assertEquals(0, connections.single { it.profileId == "eightbitdo" }.port)
        assertEquals(1, connections.single { it.profileId == "xbox" }.port)
        assertTrue(connections.all { it.pinned })
    }

    @Test
    fun `a lone pad pinned to player two stays on player two at session start`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("eightbitdo" to 0, "xbox" to 1))

        val connections = registry.activate(listOf(candidate(9, "xbox")))

        assertEquals(1, connections.single().port)
        assertTrue(connections.single().pinned)
    }

    @Test
    fun `pads pinned to players two and four stay put while player one is disconnected`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("eightbitdo" to 0, "xbox" to 1, "dualshock" to 3))

        val connections = registry.activate(
            listOf(candidate(9, "xbox"), candidate(3, "dualshock")),
        )

        assertEquals(1, connections.single { it.profileId == "xbox" }.port)
        assertEquals(3, connections.single { it.profileId == "dualshock" }.port)
        assertTrue(connections.none { it.port == 0 })
    }

    @Test
    fun `reconnecting player one fills its vacancy without moving pinned players`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("eightbitdo" to 0, "xbox" to 1, "dualshock" to 3))
        registry.activate(listOf(candidate(9, "xbox"), candidate(3, "dualshock")))

        val playerOne = registry.addOrUpdate(candidate(5, "eightbitdo"))

        assertEquals(0, playerOne.port)
        assertEquals(1, registry.connection(9)?.port)
        assertEquals(3, registry.connection(3)?.port)
    }

    @Test
    fun `identical pinned profiles resolve to the lowest device id`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("shared" to 1))

        val connections = registry.activate(listOf(candidate(8, "shared"), candidate(4, "shared")))

        assertEquals(1, connections.single { it.deviceId == 4 }.port)
        assertEquals(0, connections.single { it.deviceId == 8 }.port)
    }

    @Test
    fun `hot plug fills a vacancy without moving an assigned device`() {
        val registry = NativeControllerPortRegistry()
        registry.activate(listOf(candidate(1, "p1"), candidate(2, "p2")))

        val added = registry.addOrUpdate(candidate(3, "p3"))

        assertEquals(2, added.port)
        assertEquals(0, registry.connection(1)?.port)
        assertEquals(1, registry.connection(2)?.port)
    }

    @Test
    fun `a pinned device arriving mid session does not displace a live player`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("eightbitdo" to 0))
        registry.activate(listOf(candidate(9, "xbox")))

        val late = registry.addOrUpdate(candidate(3, "eightbitdo"))

        assertEquals(0, registry.connection(9)?.port)
        assertEquals(1, late.port)
    }

    @Test
    fun `an unpinned keyboard never takes a port but a pinned one does`() {
        val registry = NativeControllerPortRegistry()

        val unpinned = registry.activate(
            listOf(candidate(1, "pad"), candidate(2, "kbd", NativeInputDeviceClass.KEYBOARD)),
        )
        assertNull(unpinned.single { it.profileId == "kbd" }.port)

        registry.setPins(mapOf("kbd" to 1))
        val pinned = registry.activate(
            listOf(candidate(1, "pad"), candidate(2, "kbd", NativeInputDeviceClass.KEYBOARD)),
        )
        assertEquals(1, pinned.single { it.profileId == "kbd" }.port)
    }

    @Test
    fun `a remote is listed and assignable is false`() {
        val registry = NativeControllerPortRegistry()

        val connections = registry.activate(
            listOf(candidate(1, "pad"), candidate(2, "remote", NativeInputDeviceClass.REMOTE)),
        )

        val remote = connections.single { it.profileId == "remote" }
        assertNull(remote.port)
        assertFalse(remote.assignable)
        assertTrue(connections.single { it.profileId == "pad" }.assignable)
    }

    @Test
    fun `editing pins mid session reassigns immediately`() {
        val registry = NativeControllerPortRegistry()
        registry.activate(listOf(candidate(1, "a"), candidate(2, "b")))

        val connections = registry.setPins(mapOf("b" to 0, "a" to 1))

        assertEquals(0, connections.single { it.profileId == "b" }.port)
        assertEquals(1, connections.single { it.profileId == "a" }.port)
    }

    @Test
    fun `a remote counts toward navigationSourceCount`() {
        val registry = NativeControllerPortRegistry()

        registry.activate(
            listOf(candidate(1, "remote", NativeInputDeviceClass.REMOTE)),
        )

        assertEquals(1, registry.navigationSourceCount())
    }

    @Test
    fun `a ported pad does not count toward navigationSourceCount`() {
        val registry = NativeControllerPortRegistry()

        registry.activate(listOf(candidate(1, "pad")))

        assertEquals(0, registry.navigationSourceCount())
    }

    @Test
    fun `an overflow fifth gamepad does not count toward navigationSourceCount`() {
        val registry = NativeControllerPortRegistry()

        registry.activate((1..5).map { candidate(it, "p$it") })

        // p5 is portless (fifth gamepad) but is still a gamepad, not a
        // navigation source, so it is consumed and goes nowhere.
        assertEquals(0, registry.navigationSourceCount())
    }

    @Test
    fun `an unpinned keyboard counts toward navigationSourceCount`() {
        val registry = NativeControllerPortRegistry()

        registry.activate(
            listOf(candidate(1, "kbd", NativeInputDeviceClass.KEYBOARD)),
        )

        assertEquals(1, registry.navigationSourceCount())
    }

    @Test
    fun `a pinned keyboard does not count toward navigationSourceCount`() {
        val registry = NativeControllerPortRegistry()
        registry.setPins(mapOf("kbd" to 0))

        registry.activate(
            listOf(candidate(1, "kbd", NativeInputDeviceClass.KEYBOARD)),
        )

        assertEquals(0, registry.navigationSourceCount())
    }

    private fun candidate(
        deviceId: Int,
        profileId: String,
        deviceClass: NativeInputDeviceClass = NativeInputDeviceClass.GAMEPAD,
        controllerNumber: Int = 0,
    ) = NativeControllerCandidate(deviceId, profileId, profileId, controllerNumber, deviceClass)
}
