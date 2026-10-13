package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeControllerTypeParserTest {
  @Test
  fun `parses every valid advertised port entry and preserves labels`() {
    val logged = mutableListOf<NativeControllerType>()

    val types = NativeControllerTypeParser.parse(
      arrayOf("0\t1\tRetroPad", "0\t257\tSix Button", "1\t1\tDefault"),
      logged::add,
    )

    assertEquals(
      listOf(
        NativeControllerType(0, 1L, "RetroPad"),
        NativeControllerType(0, 257L, "Six Button"),
        NativeControllerType(1, 1L, "Default"),
      ),
      types,
    )
    assertEquals(types, logged)
  }

  @Test
  fun `ignores malformed and negative entries`() {
    val types = NativeControllerTypeParser.parse(
      arrayOf("bad", "0\tbad\tlabel", "-1\t2\tnegative", "0\t3"),
    )

    assertTrue(types.isEmpty())
  }

  @Test
  fun `preserves advertised ports beyond the four routed gameplay ports`() {
    assertEquals(
      listOf(NativeControllerType(7, 42L, "Extra port")),
      NativeControllerTypeParser.parse(arrayOf("7\t42\tExtra port")),
    )
  }

  @Test
  fun `allows an empty label without dropping the advertised id`() {
    assertEquals(
      listOf(NativeControllerType(2, 42L, "")),
      NativeControllerTypeParser.parse(arrayOf("2\t42\t")),
    )
  }
}
