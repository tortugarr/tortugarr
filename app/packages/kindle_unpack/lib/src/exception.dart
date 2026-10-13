/// Base type for every exception this library throws.
///
/// Lower-level parsers and decoders extend [KindleUnpackException] with
/// more specific subtypes (`PdbException`, `HeaderException`,
/// `PalmDocDecompressException`, `HuffCdicException`) so callers can
/// inspect what specifically went wrong. Use this base class to catch
/// any library-originating error uniformly.
abstract class KindleUnpackException implements Exception {
  KindleUnpackException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}
