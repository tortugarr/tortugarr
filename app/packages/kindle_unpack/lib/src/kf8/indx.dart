import 'dart:convert';
import 'dart:typed_data';

import '../headers/header_exception.dart';
import '../pdb.dart';

/// One row of the TAGX table, describing how to decode a single tag from
/// an INDX entry's control bytes + variable-width values.
class TagxEntry {
  const TagxEntry({
    required this.tag,
    required this.valuesPerEntry,
    required this.mask,
    required this.endFlag,
  });

  /// Tag identifier (matches the keys of [IndxEntry.tagMap]).
  final int tag;

  /// How many variable-width values follow per "occurrence" of this tag.
  final int valuesPerEntry;

  /// Bitmask within the active control byte that selects this tag.
  final int mask;

  /// When 1, this row isn't a real tag — it just signals "advance to the
  /// next control byte" while iterating the table.
  final int endFlag;
}

/// One decoded entry of an INDX record: a name (text key) plus a map
/// from tag → list of variable-width values.
class IndxEntry {
  const IndxEntry({required this.name, required this.tagMap});

  /// Decoded name as raw bytes. Most KF8 INDX records use ASCII, but
  /// the codepage can be 65001 (UTF-8) or 1252.
  final Uint8List name;

  /// Variable-width values for each tag found in this entry. Tags
  /// declared in TAGX but absent from this entry don't appear in the map.
  final Map<int, List<int>> tagMap;
}

/// All decoded entries of one INDX section, plus the CTOC strings the
/// entries reference.
class IndxData {
  const IndxData({
    required this.entries,
    required this.ctoc,
    required this.tagx,
  });

  /// Entries in declaration order (matches IDXT ordering).
  final List<IndxEntry> entries;

  /// CTOC string lookup. Keys are the offsets that appear in [IndxEntry]
  /// tag values; values are the raw bytes of the referenced string.
  final Map<int, Uint8List> ctoc;

  /// TAGX table that drove the decode — exposed for diagnostics.
  final List<TagxEntry> tagx;

  /// Read the INDX cluster rooted at PDB record [recordIndex]:
  /// the main INDX (with the TAGX), `count` extra INDX records that
  /// hold the actual entries, then `nctoc` CTOC records.
  ///
  /// This is a port of `MobiIndex.getIndexData` from KindleUnpack's
  /// `mobi_index.py`. ORDT-remapped names are not supported (only
  /// occurs in obscure ESP / EBCDIC files) — we throw if we see one.
  static IndxData read(PdbFile pdb, int recordIndex) {
    if (recordIndex < 0 || recordIndex >= pdb.records.length) {
      throw HeaderException(
        'INDX record $recordIndex out of range (have ${pdb.records.length})',
      );
    }
    final main = pdb.records[recordIndex].data;
    final mainHdr = _IndxHeader.parse(main);
    if (mainHdr.ordt1Count != 0) {
      throw HeaderException(
        'INDX record $recordIndex uses ORDT-remapped names; not supported',
      );
    }

    // TAGX immediately follows the fixed header.
    final tagx = _readTagx(main, mainHdr.headerLength);

    // CTOC sits after `count` extra INDX records.
    final ctocStart = recordIndex + mainHdr.indexCount + 1;
    final ctoc = <int, Uint8List>{};
    for (var i = 0; i < mainHdr.nctoc; i++) {
      final r = ctocStart + i;
      if (r >= pdb.records.length) {
        throw HeaderException(
          'CTOC record $r past end of PDB (${pdb.records.length})',
        );
      }
      _readCtoc(pdb.records[r].data, ctoc, recordOffset: i * 0x10000);
    }

    final entries = <IndxEntry>[];
    for (var i = 1; i <= mainHdr.indexCount; i++) {
      final entryRec = pdb.records[recordIndex + i].data;
      _readEntries(entryRec, tagx, entries);
    }

    return IndxData(
      entries: List.unmodifiable(entries),
      ctoc: Map.unmodifiable(ctoc),
      tagx: List.unmodifiable(tagx),
    );
  }
}

/// Parsed INDX fixed header. Internal — callers use [IndxData].
class _IndxHeader {
  _IndxHeader({
    required this.headerLength,
    required this.idxtStart,
    required this.indexCount,
    required this.codepage,
    required this.nctoc,
    required this.ordt1Count,
  });

  final int headerLength;
  final int idxtStart;
  final int indexCount;
  final int codepage;
  final int nctoc;
  final int ordt1Count;

  static _IndxHeader parse(Uint8List record) {
    if (record.length < 0x40) {
      throw HeaderException(
        'INDX record too short: ${record.length} (need at least 64 bytes)',
      );
    }
    final sig = latin1.decode(Uint8List.sublistView(record, 0, 4));
    if (sig != 'INDX') {
      throw HeaderException('expected "INDX" signature, got "$sig"');
    }
    final view = ByteData.sublistView(record);

    // Match KindleUnpack's word layout:
    //   +4   len (header length)
    //   +8   nul1
    //   +12  type (0 = main / cluster header, 1 = entry block)
    //   +16  generation
    //   +20  start (IDXT offset, only meaningful on type-1 records)
    //   +24  count (entry count for type-1; child INDX count for type-0)
    //   +28  code (codepage)
    //   +32  language
    //   +36  total entry count
    //   +40  ordt
    //   +44  ligt
    //   +48  nligt
    //   +52  nctoc (number of CTOC records that follow)
    final headerLength = view.getUint32(4);
    final idxtStart = view.getUint32(20);
    final indexCount = view.getUint32(24);
    final codepage = view.getUint32(28);
    final nctoc = view.getUint32(52);

    // ORDT detection (rarely set; bail if we see it).
    var ordt1Count = 0;
    if (record.length >= 0xa4 + 20) {
      ordt1Count = view.getUint32(0xa4);
    }

    return _IndxHeader(
      headerLength: headerLength,
      idxtStart: idxtStart,
      indexCount: indexCount,
      codepage: codepage,
      nctoc: nctoc,
      ordt1Count: ordt1Count,
    );
  }
}

List<TagxEntry> _readTagx(Uint8List record, int start) {
  if (start + 12 > record.length) {
    throw HeaderException('TAGX section past INDX record end');
  }
  final sig = latin1.decode(Uint8List.sublistView(record, start, start + 4));
  if (sig != 'TAGX') {
    throw HeaderException('expected "TAGX" signature, got "$sig"');
  }
  final view = ByteData.sublistView(record);
  final firstEntryOffset = view.getUint32(start + 4);
  final entries = <TagxEntry>[];
  for (var i = 12; i < firstEntryOffset; i += 4) {
    if (start + i + 4 > record.length) {
      throw HeaderException('TAGX row at offset ${start + i} truncated');
    }
    entries.add(
      TagxEntry(
        tag: record[start + i],
        valuesPerEntry: record[start + i + 1],
        mask: record[start + i + 2],
        endFlag: record[start + i + 3],
      ),
    );
  }
  return entries;
}

void _readCtoc(Uint8List data, Map<int, Uint8List> sink,
    {required int recordOffset}) {
  // CTOC strings: <var-int length><N bytes name>, repeated until we see
  // a 0 byte (terminator).
  var offset = 0;
  while (offset < data.length) {
    if (data[offset] == 0) break;
    final keyOffset = offset + recordOffset;
    final (consumed, length) = _readVarWidth(data, offset);
    offset += consumed;
    if (offset + length > data.length) {
      throw HeaderException(
        'CTOC string at offset ${offset - consumed} runs past record end',
      );
    }
    sink[keyOffset] = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
  }
}

void _readEntries(
  Uint8List record,
  List<TagxEntry> tagx,
  List<IndxEntry> sink,
) {
  final hdr = _IndxHeader.parse(record);
  final view = ByteData.sublistView(record);
  final idxtStart = hdr.idxtStart;
  final entryCount = hdr.indexCount;
  if (idxtStart + 4 + 2 * entryCount > record.length) {
    throw HeaderException('IDXT positions extend past INDX record end');
  }

  // Build the list of entry start offsets, plus the IDXT offset itself
  // as a sentinel "end of last entry".
  final positions = <int>[];
  for (var j = 0; j < entryCount; j++) {
    positions.add(view.getUint16(idxtStart + 4 + 2 * j));
  }
  positions.add(idxtStart);

  for (var j = 0; j < entryCount; j++) {
    final start = positions[j];
    final end = positions[j + 1];
    if (start >= record.length || start + 1 > end) continue;
    final nameLen = record[start];
    final nameStart = start + 1;
    final nameEnd = nameStart + nameLen;
    if (nameEnd > end) {
      throw HeaderException(
        'INDX entry $j name length overflows entry bounds',
      );
    }
    final name = Uint8List.sublistView(record, nameStart, nameEnd);
    final tagMap =
        _decodeTagMap(record, tagx, start: nameEnd, end: end);
    sink.add(IndxEntry(name: name, tagMap: tagMap));
  }
}

/// Decode the (tag → values) map for one INDX entry. Direct port of
/// `getTagMap` in mobi_index.py — see docs there for the bit-fiddling
/// rules. The high level is: a few control bytes select which tags are
/// present, then the variable-width value bodies follow.
Map<int, List<int>> _decodeTagMap(
  Uint8List record,
  List<TagxEntry> tagx, {
  required int start,
  required int end,
}) {
  // First, walk TAGX to figure out how many control bytes this entry
  // consumes. With endFlag rows partitioning groups, controlByteCount
  // equals the number of endFlag rows (= number of control bytes).
  // KindleUnpack stores controlByteCount in the TAGX header itself; we
  // pulled it from there too — reading from `record[start]` for the
  // first byte.
  final controlByteCount = _controlByteCountFromTagx(tagx);
  final tagsToRead = <_PendingTag>[];
  var controlByteIndex = 0;
  for (final t in tagx) {
    if (t.endFlag == 1) {
      controlByteIndex++;
      continue;
    }
    final cbyte = record[start + controlByteIndex];
    final masked = cbyte & t.mask;
    if (masked == 0) continue;
    if (masked == t.mask) {
      if (_countSetBits(t.mask) > 1) {
        // All bits set + multi-bit mask → variable-width "byte length"
        // follows the control bytes.
        tagsToRead.add(_PendingTag(
          tag: t.tag,
          valueCount: null,
          valueBytes: null, // filled in below
          valuesPerEntry: t.valuesPerEntry,
        ));
      } else {
        tagsToRead.add(_PendingTag(
          tag: t.tag,
          valueCount: 1,
          valueBytes: null,
          valuesPerEntry: t.valuesPerEntry,
        ));
      }
    } else {
      // Shift mask + value down to extract the small embedded count.
      var mask = t.mask;
      var value = masked;
      while ((mask & 0x01) == 0) {
        mask >>= 1;
        value >>= 1;
      }
      tagsToRead.add(_PendingTag(
        tag: t.tag,
        valueCount: value,
        valueBytes: null,
        valuesPerEntry: t.valuesPerEntry,
      ));
    }
  }

  // Now actually consume var-width values from the data area.
  var dataStart = start + controlByteCount;
  // First, fill in valueBytes for any pending tag whose count was "all
  // bits of the mask set" — those declare a var-int byte length here.
  for (var i = 0; i < tagsToRead.length; i++) {
    final p = tagsToRead[i];
    if (p.valueCount == null && p.valueBytes == null) {
      final (consumed, len) = _readVarWidth(record, dataStart);
      dataStart += consumed;
      tagsToRead[i] = _PendingTag(
        tag: p.tag,
        valueCount: null,
        valueBytes: len,
        valuesPerEntry: p.valuesPerEntry,
      );
    }
  }

  final out = <int, List<int>>{};
  for (final p in tagsToRead) {
    final values = <int>[];
    if (p.valueCount != null) {
      final total = p.valueCount! * p.valuesPerEntry;
      for (var k = 0; k < total; k++) {
        final (consumed, v) = _readVarWidth(record, dataStart);
        dataStart += consumed;
        values.add(v);
      }
    } else {
      // Read until we've consumed exactly `valueBytes` bytes of input.
      final target = dataStart + p.valueBytes!;
      while (dataStart < target) {
        final (consumed, v) = _readVarWidth(record, dataStart);
        dataStart += consumed;
        values.add(v);
      }
    }
    out[p.tag] = values;
    if (dataStart > end) {
      throw HeaderException(
        'INDX entry tag ${p.tag} consumed past entry end',
      );
    }
  }
  return out;
}

/// Forward-reading variable-width int. Each byte contributes 7 bits;
/// the byte with the high bit set marks the end of the integer.
(int consumed, int value) _readVarWidth(Uint8List data, int offset) {
  var value = 0;
  var consumed = 0;
  while (true) {
    if (offset + consumed >= data.length) {
      throw HeaderException(
        'variable-width int at offset $offset runs past buffer end',
      );
    }
    final v = data[offset + consumed];
    consumed += 1;
    value = (value << 7) | (v & 0x7F);
    if ((v & 0x80) != 0) return (consumed, value);
  }
}

int _controlByteCountFromTagx(List<TagxEntry> tagx) {
  var n = 0;
  for (final t in tagx) {
    if (t.endFlag == 1) n++;
  }
  return n;
}

int _countSetBits(int v) {
  var n = 0;
  var x = v;
  while (x != 0) {
    n += x & 1;
    x >>= 1;
  }
  return n;
}

class _PendingTag {
  _PendingTag({
    required this.tag,
    required this.valueCount,
    required this.valueBytes,
    required this.valuesPerEntry,
  });

  final int tag;
  final int? valueCount;
  final int? valueBytes;
  final int valuesPerEntry;
}
