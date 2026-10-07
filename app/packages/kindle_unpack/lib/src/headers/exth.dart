import 'dart:convert';
import 'dart:typed_data';

import 'header_exception.dart';

/// Numeric type codes for the most common EXTH records.
///
/// EXTH stores book metadata (author, publisher, ASIN, cover-image record
/// pointer, KF8 boundary, …) as a flat list of (type, bytes) records. The
/// MOBI ecosystem has accumulated dozens of type codes over the years; this
/// list covers the ones we expose typed accessors for, and is not
/// exhaustive — unknown codes are still parsed and available via
/// [ExthHeader.rawValues].
class ExthType {
  ExthType._();

  static const int author = 100;
  static const int publisher = 101;
  static const int imprint = 102;
  static const int description = 103;
  static const int isbn = 104;
  static const int subject = 105;
  static const int publishedDate = 106;
  static const int review = 107;
  static const int contributor = 108;
  static const int rights = 109;
  static const int subjectCode = 110;
  static const int bookType = 111;
  static const int source = 112;
  static const int asin = 113;
  static const int versionNumber = 114;
  static const int isSample = 115;
  static const int startReading = 116;
  static const int retailPrice = 118;
  static const int retailPriceCurrency = 119;
  static const int kf8BoundaryRecord = 121;
  static const int coverOffset = 201;
  static const int thumbnailOffset = 202;
  static const int hasFakeCover = 203;
  static const int creatorSoftware = 204;
  static const int creatorMajorVersion = 205;
  static const int creatorMinorVersion = 206;
  static const int creatorBuildNumber = 207;
  static const int watermark = 208;
  static const int cdeType = 501;
  static const int updatedTitle = 503;
  static const int asinAlt = 504;
  static const int language = 524;
}

/// A single EXTH record: a type code plus the raw bytes following it.
class ExthRecord {
  const ExthRecord({required this.type, required this.data});

  final int type;
  final Uint8List data;

  int get length => data.length;
}

/// The EXTH header is a flat list of metadata records that follows the
/// MOBI header inside record 0. This class parses the signature/length/
/// count, slices each record (zero-copy), and exposes both raw lookups
/// and decoded convenience accessors.
class ExthHeader {
  ExthHeader._({
    required this.records,
    required this.textEncoding,
    required Map<int, List<ExthRecord>> byType,
  }) : _byType = byType;

  /// 4-byte signature at the start of the EXTH header.
  static const String signature = 'EXTH';

  /// All records in declaration order.
  final List<ExthRecord> records;

  /// Codepage from the MOBI header (1252 or 65001). Used to decode string
  /// values into Dart strings.
  final int textEncoding;

  final Map<int, List<ExthRecord>> _byType;

  /// All records grouped by type code, preserving in-file order.
  Map<int, List<ExthRecord>> get byType => Map.unmodifiable(_byType);

  /// Raw bytes of the first record matching [type], or null if absent.
  Uint8List? rawValue(int type) => _byType[type]?.first.data;

  /// Raw bytes of every record matching [type], in declaration order.
  /// Empty list if none.
  List<Uint8List> rawValues(int type) =>
      _byType[type]?.map((r) => r.data).toList(growable: false) ??
      const <Uint8List>[];

  /// Decoded string value of the first record matching [type], or null
  /// if absent. Decoded with UTF-8 when [textEncoding] is 65001, latin1
  /// otherwise (a close-enough stand-in for Windows-1252).
  String? stringValue(int type) {
    final v = rawValue(type);
    return v == null ? null : _decode(v);
  }

  /// Decoded string values for every record matching [type], in order.
  List<String> stringValues(int type) =>
      rawValues(type).map(_decode).toList(growable: false);

  /// Big-endian uint32 stored in [type]'s record, or null if absent or if
  /// the record isn't exactly 4 bytes.
  int? uint32Value(int type) {
    final v = rawValue(type);
    if (v == null || v.length != 4) return null;
    return ByteData.sublistView(v).getUint32(0);
  }

  // --- Convenience accessors ---------------------------------------------

  /// Title preferred over the MOBI header's `fullName`. EXTH 503 is the
  /// canonical updated title; not all files set it.
  String? get title => stringValue(ExthType.updatedTitle);

  List<String> get authors => stringValues(ExthType.author);
  String? get publisher => stringValue(ExthType.publisher);
  String? get imprint => stringValue(ExthType.imprint);
  String? get description => stringValue(ExthType.description);
  String? get isbn => stringValue(ExthType.isbn);
  List<String> get subjects => stringValues(ExthType.subject);
  String? get publishedDate => stringValue(ExthType.publishedDate);
  String? get rights => stringValue(ExthType.rights);
  List<String> get contributors => stringValues(ExthType.contributor);

  /// Amazon Standard Identification Number. Falls back to type 504 when
  /// 113 is absent; some publishers set one or the other.
  String? get asin =>
      stringValue(ExthType.asin) ?? stringValue(ExthType.asinAlt);

  /// 4-letter "CDE" content type — EBOK (book), EBSP (sample), PDOC
  /// (personal document), MAGZ, NWPR, etc.
  String? get cdeType => stringValue(ExthType.cdeType);

  /// IETF-style language tag, e.g. `en-us`.
  String? get language => stringValue(ExthType.language);

  /// 0-based image record index of the cover image (relative to the first
  /// image record, not the PDB record list). `null` if no cover EXTH entry.
  int? get coverOffset => uint32Value(ExthType.coverOffset);

  /// Same convention as [coverOffset], for the thumbnail.
  int? get thumbnailOffset => uint32Value(ExthType.thumbnailOffset);

  /// In dual MOBI/KF8 files, the 1-based PDB record index after which the
  /// KF8 portion begins. `null` for pure-MOBI files.
  int? get kf8BoundaryRecord => uint32Value(ExthType.kf8BoundaryRecord);

  // -----------------------------------------------------------------------

  /// Parse the EXTH header sitting at [offset] inside [record0]. Pass the
  /// MOBI header's [textEncoding] so string accessors decode correctly.
  static ExthHeader parse(
    Uint8List record0, {
    required int offset,
    required int textEncoding,
  }) {
    if (offset < 0 || offset + 12 > record0.length) {
      throw HeaderException(
        'EXTH header offset $offset out of range '
        '(record 0 length ${record0.length})',
      );
    }
    final view = ByteData.sublistView(record0);

    final sig = latin1.decode(
      Uint8List.sublistView(record0, offset, offset + 4),
    );
    if (sig != signature) {
      throw HeaderException('expected "$signature" signature, got "$sig"');
    }

    final headerLength = view.getUint32(offset + 4);
    final recordCount = view.getUint32(offset + 8);

    if (headerLength < 12) {
      throw HeaderException(
        'EXTH header length too small: $headerLength (need >= 12)',
      );
    }
    if (offset + headerLength > record0.length) {
      throw HeaderException(
        'EXTH header (length $headerLength) extends past record 0 '
        '(${record0.length})',
      );
    }

    final records = <ExthRecord>[];
    final byType = <int, List<ExthRecord>>{};

    var cursor = offset + 12;
    final headerEnd = offset + headerLength;
    for (var i = 0; i < recordCount; i++) {
      if (cursor + 8 > headerEnd) {
        throw HeaderException(
          'EXTH record $i header runs past EXTH end '
          '(cursor $cursor, end $headerEnd)',
        );
      }
      final type = view.getUint32(cursor);
      final recLen = view.getUint32(cursor + 4);
      if (recLen < 8) {
        throw HeaderException(
          'EXTH record $i length too small: $recLen (need >= 8)',
        );
      }
      if (cursor + recLen > headerEnd) {
        throw HeaderException(
          'EXTH record $i (length $recLen) runs past EXTH end',
        );
      }
      final data =
          Uint8List.sublistView(record0, cursor + 8, cursor + recLen);
      final record = ExthRecord(type: type, data: data);
      records.add(record);
      (byType[type] ??= <ExthRecord>[]).add(record);
      cursor += recLen;
    }

    return ExthHeader._(
      records: List<ExthRecord>.unmodifiable(records),
      textEncoding: textEncoding,
      byType: byType,
    );
  }

  String _decode(Uint8List bytes) {
    return textEncoding == 65001
        ? utf8.decode(bytes, allowMalformed: true)
        : latin1.decode(bytes);
  }
}
