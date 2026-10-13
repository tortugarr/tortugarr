import 'dart:typed_data';

import '../headers/header_exception.dart';
import '../headers/mobi_header.dart';
import '../headers/palmdoc_header.dart';
import '../pdb.dart';
import 'huff_cdic.dart';
import 'palmdoc.dart';
import 'trailing_data.dart';

/// Decompress and concatenate every text record in a MOBI book.
///
/// Text records are PDB records 1..[PalmDocHeader.textRecordCount]. Each
/// record is first stripped of its trailing-data entries (per
/// [MobiHeader.extraDataFlags]) and then run through the appropriate
/// decompressor for [PalmDocHeader.compression]. For HUFF/CDIC files,
/// the HUFF + CDIC records pointed at by [MobiHeader.huffmanRecordOffset]
/// / [MobiHeader.huffmanRecordCount] are loaded once and shared across
/// all text records.
///
/// Returns the raw uncompressed bytes of the book's text. Decoding to a
/// string is the caller's job — the bytes are in [MobiHeader.textEncoding].
///
/// Throws [HeaderException] for encrypted files or malformed metadata,
/// and [HuffCdicException] for malformed HUFF/CDIC records.
Uint8List decompressBookText({
  required PdbFile pdb,
  required PalmDocHeader palmDoc,
  required MobiHeader mobi,
}) {
  if (palmDoc.isEncrypted || mobi.hasDrm) {
    throw HeaderException(
      'cannot decompress encrypted MOBI (encryption=${palmDoc.encryption}, '
      'hasDrm=${mobi.hasDrm})',
    );
  }

  final count = palmDoc.textRecordCount;
  if (count == 0) return Uint8List(0);
  if (1 + count > pdb.records.length) {
    throw HeaderException(
      'PalmDOC header advertises $count text records but PDB only has '
      '${pdb.records.length - 1} records past record 0',
    );
  }

  // Build the HUFF/CDIC decoder up front so we don't re-parse the tables
  // for every text record.
  HuffTable? huff;
  CdicTable? cdic;
  if (palmDoc.compression == CompressionType.huffCdic) {
    final huffOff = mobi.huffmanRecordOffset;
    final huffCount = mobi.huffmanRecordCount;
    if (huffOff == 0 || huffCount < 2) {
      throw HeaderException(
        'HUFF/CDIC compression but MOBI header has no HUFF/CDIC records '
        '(offset=$huffOff, count=$huffCount)',
      );
    }
    if (huffOff + huffCount > pdb.records.length) {
      throw HeaderException(
        'HUFF/CDIC records [$huffOff..${huffOff + huffCount}) extend past '
        'PDB record list (${pdb.records.length})',
      );
    }
    huff = HuffTable.parse(pdb.records[huffOff].data);
    cdic = CdicTable.parse([
      for (var i = huffOff + 1; i < huffOff + huffCount; i++)
        pdb.records[i].data,
    ]);
  }

  final flags = mobi.extraDataFlags;
  final out = BytesBuilder(copy: false);
  for (var i = 1; i <= count; i++) {
    final raw = pdb.records[i].data;
    final payload = stripTrailingDataEntries(raw, flags);
    switch (palmDoc.compression) {
      case CompressionType.none:
        out.add(payload);
      case CompressionType.palmDoc:
        out.add(decompressPalmDoc(payload));
      case CompressionType.huffCdic:
        out.add(
          decompressHuffCdic(input: payload, huff: huff!, cdic: cdic!),
        );
    }
  }
  return out.toBytes();
}
