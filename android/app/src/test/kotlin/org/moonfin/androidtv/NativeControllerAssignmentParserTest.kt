package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeControllerAssignmentParserTest {
    @Test
    fun `player numbers convert to zero based ports`() {
        val pins = NativeControllerAssignmentParser.parse(
            """{"players":{"1":"android-aaa","4":"android-bbb"}}""",
        )

        assertEquals(mapOf("android-aaa" to 0, "android-bbb" to 3), pins)
    }

    @Test
    fun `players outside one through four are dropped`() {
        val pins = NativeControllerAssignmentParser.parse(
            """{"players":{"0":"android-aaa","5":"android-bbb","2":"android-ccc"}}""",
        )

        assertEquals(mapOf("android-ccc" to 1), pins)
    }

    @Test
    fun `a profile claimed by two players keeps the lower player`() {
        val pins = NativeControllerAssignmentParser.parse(
            """{"players":{"3":"android-aaa","2":"android-aaa"}}""",
        )

        assertEquals(mapOf("android-aaa" to 1), pins)
    }

    @Test
    fun `blank and non numeric entries are ignored`() {
        val pins = NativeControllerAssignmentParser.parse(
            """{"players":{"1":"","two":"android-bbb","3":"android-ccc"}}""",
        )

        assertEquals(mapOf("android-ccc" to 2), pins)
    }

    @Test
    fun `missing malformed and empty payloads yield no pins`() {
        assertTrue(NativeControllerAssignmentParser.parse("{}").isEmpty())
        assertTrue(NativeControllerAssignmentParser.parse("not json").isEmpty())
        assertTrue(NativeControllerAssignmentParser.parse("""{"players":[]}""").isEmpty())
    }
}
