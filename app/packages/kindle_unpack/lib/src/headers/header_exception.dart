import '../exception.dart';

/// Thrown when record 0's headers (PalmDOC / MOBI / EXTH) — or any of
/// the typed structural records the parser builds on top of them
/// (FDST, FONT, RESC, BookFlows, XhtmlSplitter, …) — cannot be parsed.
class HeaderException extends KindleUnpackException {
  HeaderException(super.message);
}
