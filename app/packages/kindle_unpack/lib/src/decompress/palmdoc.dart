import 'dart:typed_data';

import '../exception.dart';

/// Thrown when a PalmDOC-compressed input can't be decoded.
class PalmDocDecompressException extends KindleUnpackException {
  PalmDocDecompressException(super.message);
}

/// Decompress a single PalmDOC-compressed byte stream.
///
/// PalmDOC is a one-pass byte-coded LZ77 variant. Each control byte `c`
/// dispatches to one of four opcode classes:
///
/// - `0x00` and `0x09..0x7F`: emit `c` literally.
/// - `0x01..0x08`: read the next `c` bytes verbatim and emit them.
/// - `0x80..0xBF`: a 2-byte back-reference. The 14 bits below the `10`
///   prefix split into 11 bits of distance (1..2047, measured back from
///   the current output cursor) and 3 bits of length (encoded as
///   `length - 3`, so the actual length is 3..10). Bytes are copied one
///   at a time, so overlapping copies (`distance < length`) produce
///   repeating patterns.
/// - `0xC0..0xFF`: a "space pair" — emit `0x20` followed by `c ^ 0x80`.
///
/// The decoder is strict: a back-reference whose distance is zero or
/// would read before the start of the output buffer throws. A literal
/// run that would read past the end of the input throws.
Uint8List decompressPalmDoc(Uint8List input) {
  final out = <int>[];
  var i = 0;
  final n = input.length;

  while (i < n) {
    final c = input[i++];

    if (c == 0 || (c >= 0x09 && c <= 0x7F)) {
      out.add(c);
    } else if (c >= 0x01 && c <= 0x08) {
      if (i + c > n) {
        throw PalmDocDecompressException(
          'literal run of $c bytes at offset ${i - 1} runs past input '
          '(length $n)',
        );
      }
      for (var j = 0; j < c; j++) {
        out.add(input[i + j]);
      }
      i += c;
    } else if (c >= 0x80 && c <= 0xBF) {
      if (i >= n) {
        throw PalmDocDecompressException(
          'back-reference at offset ${i - 1} truncated — missing low byte',
        );
      }
      final c2 = input[i++];
      final combined = ((c << 8) | c2) & 0x3FFF;
      final distance = combined >> 3;
      final length = (combined & 0x07) + 3;
      if (distance == 0) {
        throw PalmDocDecompressException(
          'back-reference at offset ${i - 2} has distance 0',
        );
      }
      final src = out.length - distance;
      if (src < 0) {
        throw PalmDocDecompressException(
          'back-reference at offset ${i - 2} reads before start of output '
          '(distance $distance, output ${out.length})',
        );
      }
      // Copy byte-by-byte from the live output. When distance < length,
      // each appended byte feeds the next read, producing run-length
      // patterns — that's the LZ77 trick that compresses repeated chars.
      for (var j = 0; j < length; j++) {
        out.add(out[src + j]);
      }
    } else {
      // c >= 0xC0: space-pair shortcut.
      out.add(0x20);
      out.add(c ^ 0x80);
    }
  }

  return Uint8List.fromList(out);
}
