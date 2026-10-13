import 'dart:convert';
import 'dart:typed_data';

import '../headers/header_exception.dart';

/// One entry in the FDST table: a half-open byte range [start, end)
/// inside the decompressed KF8 raw-ML stream.
class FdstEntry {
  const FdstEntry({required this.start, required this.end});

  /// Inclusive byte offset where this section starts.
  final int start;

  /// Exclusive byte offset where this section ends. For consecutive
  /// entries this equals the next entry's [start].
  final int end;

  int get length => end - start;
}

/// The FDST record splits a KF8 book's decompressed text (raw-ML) into
/// sections. The text body is a concatenation of HTML, CSS, SVG, NCX
/// fragments, etc., and FDST tells us where each section lives so the
/// EPUB packager can split them back into separate files.
class FdstTable {
  const FdstTable({required this.entries});

  static const String signature = 'FDST';

  /// Sections in declaration order. Real files have these covering a
  /// contiguous range starting at offset 0; the parser doesn't enforce
  /// that — leave it to consumers that care.
  final List<FdstEntry> entries;

  int get sectionCount => entries.length;

  /// Parse an FDST record. Layout (from KindleUnpack mobi_k8proc.py):
  ///
  ///   0..3   "FDST"
  ///   4..7   header length (informational; usually 12)
  ///   8..11  number of sections (uint32 BE)
  ///   12..   `sections * 8` bytes of (start, end) uint32 BE pairs
  static FdstTable parse(Uint8List record) {
    if (record.length < 12) {
      throw HeaderException(
        'FDST record too short: ${record.length} bytes (need 12+ for header)',
      );
    }
    final view = ByteData.sublistView(record);
    final sig = latin1.decode(Uint8List.sublistView(record, 0, 4));
    if (sig != signature) {
      throw HeaderException('expected "$signature" signature, got "$sig"');
    }

    final sections = view.getUint32(8);
    final entriesEnd = 12 + sections * 8;
    if (entriesEnd > record.length) {
      throw HeaderException(
        'FDST record advertises $sections sections '
        '(needs $entriesEnd bytes) but is only ${record.length} bytes',
      );
    }

    final entries = List<FdstEntry>.generate(sections, (i) {
      final start = view.getUint32(12 + i * 8);
      final end = view.getUint32(12 + i * 8 + 4);
      return FdstEntry(start: start, end: end);
    }, growable: false);

    return FdstTable(entries: List<FdstEntry>.unmodifiable(entries));
  }
}
