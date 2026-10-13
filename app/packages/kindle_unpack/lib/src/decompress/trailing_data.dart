import 'dart:typed_data';

import '../headers/header_exception.dart';

/// Compute the total length of trailing-data entries appended to a
/// MOBI text record, given the `extra record data flags` bitfield from
/// the MOBI header (offset 0xF2).
///
/// The flags bitfield works as follows:
/// - Each bit `i > 0` set means the record has a length-prefixed trailer
///   for category `i` appended at its end. The length is a backwards
///   variable-width integer: bytes are read from the *end* of the record
///   going backward, each contributing 7 bits to the result; a byte with
///   the high bit set marks the last (most-significant) byte of the int.
///   The decoded value is the trailer's total length, including the
///   bytes that encode it.
/// - Bit 0 set means the record ends with a "multibyte char overlap"
///   indicator: a single byte whose low 2 bits + 1 give how many bytes
///   at the end of the record belong to a multi-byte char that started
///   in the previous record. We strip that 1 indicator byte plus the
///   bytes it points at.
///
/// All bit-`i>0` trailers are stripped first (each pointing at the *new*
/// end as we shrink), then the bit-0 indicator is consumed last.
int sizeOfTrailingDataEntries(Uint8List record, int flags) {
  int sizeOfOne(int end) {
    var bitpos = 0;
    var result = 0;
    var pos = end;
    while (pos > 0) {
      final v = record[pos - 1];
      result |= (v & 0x7F) << bitpos;
      bitpos += 7;
      pos -= 1;
      if ((v & 0x80) != 0 || bitpos >= 28) break;
    }
    return result;
  }

  var num = 0;
  var testflags = flags >> 1;
  while (testflags != 0) {
    if ((testflags & 1) != 0) {
      num += sizeOfOne(record.length - num);
    }
    testflags >>= 1;
  }
  if ((flags & 1) != 0) {
    if (record.length - num - 1 < 0) {
      throw HeaderException(
        'multibyte-overlap indicator points before record start',
      );
    }
    num += (record[record.length - num - 1] & 0x3) + 1;
  }
  return num;
}

/// Return a view of [record] with its trailing data entries stripped, so
/// the result is the raw compressed payload (PalmDOC or HUFF/CDIC).
/// When [flags] is 0 this is a no-op.
Uint8List stripTrailingDataEntries(Uint8List record, int flags) {
  if (flags == 0) return record;
  final size = sizeOfTrailingDataEntries(record, flags);
  if (size < 0 || size > record.length) {
    throw HeaderException(
      'trailing-data size $size out of range for record length '
      '${record.length}',
    );
  }
  return Uint8List.sublistView(record, 0, record.length - size);
}
