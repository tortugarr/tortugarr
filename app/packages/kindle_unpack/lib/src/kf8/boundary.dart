import 'dart:convert';
import 'dart:typed_data';

import '../headers/exth.dart';
import '../headers/header_exception.dart';
import '../headers/mobi_header.dart';
import '../headers/palmdoc_header.dart';
import '../pdb.dart';

/// Top-level shape of a Kindle file's contents.
enum KindleFormat {
  /// Record 0 is a Mobi-7 header and there is no KF8 portion.
  mobi7Only,

  /// Record 0 is a KF8 header; the file has no Mobi-7 portion at all.
  kf8Only,

  /// Record 0 is a Mobi-7 header and the file ALSO contains a KF8
  /// portion starting at [KindleFile.kf8].`recordOffset`. Old Kindles
  /// read the Mobi-7 part; modern ones read the KF8 part.
  combo,
}

/// One coherent section of a Kindle file — a Mobi-7 or KF8 portion that
/// has its own PalmDOC header, MOBI header, and (typically) EXTH header
/// inside its `record 0`.
class KindleSection {
  const KindleSection({
    required this.recordOffset,
    required this.recordCount,
    required this.palmDoc,
    required this.mobi,
    required this.exth,
  });

  /// PDB record index of this section's "record 0".
  final int recordOffset;

  /// Number of PDB records that belong to this section
  /// (`[recordOffset, recordOffset + recordCount)`).
  final int recordCount;

  final PalmDocHeader palmDoc;
  final MobiHeader mobi;

  /// Null when [MobiHeader.hasExth] is false.
  final ExthHeader? exth;
}

/// Top-level view of a Kindle file: format + Mobi-7 / KF8 sections.
/// Build with [KindleFile.inspect].
class KindleFile {
  const KindleFile._({
    required this.format,
    required this.mobi7,
    required this.kf8,
  });

  final KindleFormat format;

  /// Mobi-7 section. Null only when [format] is [KindleFormat.kf8Only].
  final KindleSection? mobi7;

  /// KF8 section. Null only when [format] is [KindleFormat.mobi7Only].
  final KindleSection? kf8;

  /// Detect the format of [pdb] and parse each section's headers.
  ///
  /// Detection rules (matching KindleUnpack's `mobi_split.py`):
  ///   * If `record 0`'s MOBI `fileVersion >= 8`, this is a standalone
  ///     KF8 file — no Mobi-7 portion.
  ///   * Otherwise, look at EXTH 121 (`kf8BoundaryRecord`). If it points
  ///     at a valid PDB record AND the previous record starts with the
  ///     ASCII string `"BOUNDARY"`, the file is a combo and the KF8
  ///     section starts at that record.
  ///   * Anything else is Mobi-7 only.
  static KindleFile inspect(PdbFile pdb) {
    if (pdb.records.isEmpty) {
      throw HeaderException('PDB has no records to inspect');
    }
    final r0 = pdb.records[0].data;
    final palmDoc = PalmDocHeader.parse(r0);
    final mobi = MobiHeader.parse(r0);
    final exth = mobi.hasExth
        ? ExthHeader.parse(
            r0,
            offset: mobi.exthOffset,
            textEncoding: mobi.textEncoding,
          )
        : null;

    if (mobi.fileVersion >= 8) {
      return KindleFile._(
        format: KindleFormat.kf8Only,
        mobi7: null,
        kf8: KindleSection(
          recordOffset: 0,
          recordCount: pdb.records.length,
          palmDoc: palmDoc,
          mobi: mobi,
          exth: exth,
        ),
      );
    }

    // Mobi-7 record 0 — check for an embedded KF8 section.
    final boundary = exth?.kf8BoundaryRecord;
    if (boundary != null &&
        boundary != MobiHeader.unset &&
        boundary > 0 &&
        boundary < pdb.records.length &&
        _looksLikeBoundarySentinel(pdb.records[boundary - 1].data)) {
      final kf8R0 = pdb.records[boundary].data;
      final kf8PalmDoc = PalmDocHeader.parse(kf8R0);
      final kf8Mobi = MobiHeader.parse(kf8R0);
      final kf8Exth = kf8Mobi.hasExth
          ? ExthHeader.parse(
              kf8R0,
              offset: kf8Mobi.exthOffset,
              textEncoding: kf8Mobi.textEncoding,
            )
          : null;
      return KindleFile._(
        format: KindleFormat.combo,
        mobi7: KindleSection(
          recordOffset: 0,
          recordCount: boundary,
          palmDoc: palmDoc,
          mobi: mobi,
          exth: exth,
        ),
        kf8: KindleSection(
          recordOffset: boundary,
          recordCount: pdb.records.length - boundary,
          palmDoc: kf8PalmDoc,
          mobi: kf8Mobi,
          exth: kf8Exth,
        ),
      );
    }

    return KindleFile._(
      format: KindleFormat.mobi7Only,
      mobi7: KindleSection(
        recordOffset: 0,
        recordCount: pdb.records.length,
        palmDoc: palmDoc,
        mobi: mobi,
        exth: exth,
      ),
      kf8: null,
    );
  }
}

bool _looksLikeBoundarySentinel(Uint8List record) {
  if (record.length < 8) return false;
  return latin1.decode(Uint8List.sublistView(record, 0, 8)) == 'BOUNDARY';
}
