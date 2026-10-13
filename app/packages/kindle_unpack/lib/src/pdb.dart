import 'dart:convert';
import 'dart:typed_data';

import 'exception.dart';

/// Thrown when a byte stream cannot be parsed as a Palm Database.
class PdbException extends KindleUnpackException {
  PdbException(super.message);
}

/// Fixed-size header that sits at the start of every Palm Database file.
///
/// All multi-byte fields are big-endian. Date fields are exposed as their
/// raw uint32 value; the canonical interpretation is "seconds since
/// 1904-01-01 UTC" (Palm/Mac epoch), but real-world files vary, so the
/// caller decides how to convert.
class PdbHeader {
  const PdbHeader({
    required this.name,
    required this.attributes,
    required this.version,
    required this.creationDate,
    required this.modificationDate,
    required this.lastBackupDate,
    required this.modificationNumber,
    required this.appInfoId,
    required this.sortInfoId,
    required this.type,
    required this.creator,
    required this.uniqueIdSeed,
    required this.recordCount,
  });

  final String name;
  final int attributes;
  final int version;
  final int creationDate;
  final int modificationDate;
  final int lastBackupDate;
  final int modificationNumber;
  final int appInfoId;
  final int sortInfoId;
  final String type;
  final String creator;
  final int uniqueIdSeed;
  final int recordCount;
}

/// A single PDB record: a slice of the file's bytes plus its metadata entry.
class PdbRecord {
  const PdbRecord({
    required this.offset,
    required this.attributes,
    required this.uniqueId,
    required this.data,
  });

  /// Byte offset of [data] from the start of the original PDB file.
  final int offset;

  /// 8-bit record attributes (delete, dirty, busy, secret).
  final int attributes;

  /// 24-bit record-local unique ID.
  final int uniqueId;

  /// View into the original byte buffer for this record's payload.
  final Uint8List data;

  int get length => data.length;
}

/// A parsed Palm Database file: header plus the list of record slices.
class PdbFile {
  const PdbFile({required this.header, required this.records});

  final PdbHeader header;
  final List<PdbRecord> records;

  /// Parse [bytes] as a PDB file. Returns a [PdbFile] sharing the input
  /// buffer for record payloads (no copy). Throws [PdbException] on
  /// malformed input.
  static PdbFile parse(Uint8List bytes) {
    if (bytes.length < _headerSize) {
      throw PdbException(
        'file too short: ${bytes.length} bytes < $_headerSize header bytes',
      );
    }

    final view = ByteData.sublistView(bytes);

    final name = _readCString(bytes, 0, 32);
    final attributes = view.getUint16(32);
    final version = view.getUint16(34);
    final creationDate = view.getUint32(36);
    final modificationDate = view.getUint32(40);
    final lastBackupDate = view.getUint32(44);
    final modificationNumber = view.getUint32(48);
    final appInfoId = view.getUint32(52);
    final sortInfoId = view.getUint32(56);
    final type = _readAscii(bytes, 60, 4);
    final creator = _readAscii(bytes, 64, 4);
    final uniqueIdSeed = view.getUint32(68);
    // 72..75 is nextRecordListID; always 0 in single-segment PDBs. Skipped.
    final recordCount = view.getUint16(76);

    final recordListEnd = _headerSize + recordCount * _recordEntrySize;
    if (bytes.length < recordListEnd) {
      throw PdbException(
        'truncated record list: need $recordListEnd bytes for $recordCount '
        'entries, have ${bytes.length}',
      );
    }

    final offsets = List<int>.filled(recordCount, 0);
    final attrs = List<int>.filled(recordCount, 0);
    final uids = List<int>.filled(recordCount, 0);
    for (var i = 0; i < recordCount; i++) {
      final base = _headerSize + i * _recordEntrySize;
      offsets[i] = view.getUint32(base);
      attrs[i] = view.getUint8(base + 4);
      uids[i] = (view.getUint8(base + 5) << 16) |
          (view.getUint8(base + 6) << 8) |
          view.getUint8(base + 7);
    }

    for (var i = 0; i < recordCount; i++) {
      final off = offsets[i];
      if (off < recordListEnd) {
        throw PdbException(
          'record $i offset $off lies inside header/record-list area '
          '(< $recordListEnd)',
        );
      }
      if (off > bytes.length) {
        throw PdbException(
          'record $i offset $off past end of file (${bytes.length})',
        );
      }
      if (i > 0 && off < offsets[i - 1]) {
        throw PdbException(
          'record offsets not monotonically increasing at index $i '
          '(${offsets[i - 1]} -> $off)',
        );
      }
    }

    final records = <PdbRecord>[];
    for (var i = 0; i < recordCount; i++) {
      final start = offsets[i];
      final end = (i + 1 < recordCount) ? offsets[i + 1] : bytes.length;
      records.add(
        PdbRecord(
          offset: start,
          attributes: attrs[i],
          uniqueId: uids[i],
          data: Uint8List.sublistView(bytes, start, end),
        ),
      );
    }

    return PdbFile(
      header: PdbHeader(
        name: name,
        attributes: attributes,
        version: version,
        creationDate: creationDate,
        modificationDate: modificationDate,
        lastBackupDate: lastBackupDate,
        modificationNumber: modificationNumber,
        appInfoId: appInfoId,
        sortInfoId: sortInfoId,
        type: type,
        creator: creator,
        uniqueIdSeed: uniqueIdSeed,
        recordCount: recordCount,
      ),
      records: List<PdbRecord>.unmodifiable(records),
    );
  }
}

const int _headerSize = 78;
const int _recordEntrySize = 8;

String _readCString(Uint8List bytes, int start, int length) {
  var end = start + length;
  for (var i = start; i < start + length; i++) {
    if (bytes[i] == 0) {
      end = i;
      break;
    }
  }
  return latin1.decode(Uint8List.sublistView(bytes, start, end));
}

String _readAscii(Uint8List bytes, int start, int length) {
  return latin1.decode(Uint8List.sublistView(bytes, start, start + length));
}
