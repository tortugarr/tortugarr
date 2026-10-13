package org.moonfin.androidtv

import org.junit.Assert.assertEquals
import org.junit.Test

class NativeControllerMappingParserTest {
  @Test
  fun `malformed structured payload falls back to no mappings`() {
    assertEquals(
      emptyMap<String, Map<Int, Int>>(),
      NativeControllerMappingParser.parse("not-json"),
    )
  }
}
