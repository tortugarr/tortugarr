package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeInputDescriptorParserTest {
  @Test
  fun `parses every valid descriptor entry and preserves descriptions`() {
    val logged = mutableListOf<NativeInputDescriptor>()

    val descriptors = NativeInputDescriptorParser.parse(
      arrayOf("0\t1\t0\t0\tFire", "0\t1\t0\t8\tJump", "1\t1\t0\t0\tP2 Fire"),
      logged::add,
    )

    assertEquals(
      listOf(
        NativeInputDescriptor(0, 1L, 0, 0L, "Fire"),
        NativeInputDescriptor(0, 1L, 0, 8L, "Jump"),
        NativeInputDescriptor(1, 1L, 0, 0L, "P2 Fire"),
      ),
      descriptors,
    )
    assertEquals(descriptors, logged)
  }

  @Test
  fun `ignores malformed and negative entries`() {
    val descriptors = NativeInputDescriptorParser.parse(
      arrayOf("bad", "0\t1\t0\tbad\tlabel", "-1\t1\t0\t2\tnegative port",
        "0\t1\t0\t2"),
    )

    assertTrue(descriptors.isEmpty())
  }

  @Test
  fun `keeps a tab inside the description intact`() {
    assertEquals(
      listOf(NativeInputDescriptor(0, 1L, 0, 0L, "Fire\tSecondary")),
      NativeInputDescriptorParser.parse(arrayOf("0\t1\t0\t0\tFire\tSecondary")),
    )
  }

  @Test
  fun `allows an empty description without dropping the advertised id`() {
    assertEquals(
      listOf(NativeInputDescriptor(0, 1L, 0, 0L, "")),
      NativeInputDescriptorParser.parse(arrayOf("0\t1\t0\t0\t")),
    )
  }
}
