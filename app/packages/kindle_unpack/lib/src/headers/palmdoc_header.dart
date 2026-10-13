import 'dart:typed_data';

import 'header_exception.dart';

/// Compression scheme used for the book's text records.
enum CompressionType {
  none(1),
  palmDoc(2),
  huffCdic(17480);

  const CompressionType(this.code);

  final int code;

  static CompressionType fromCode(int code) {
    for (final c in CompressionType.values) {
      if (c.code == code) return c;
    }
    throw HeaderException('unknown PalmDOC compression code: $code');
  }
}

/// Encryption flag carried in the PalmDOC header.
enum EncryptionType {
  none(0),
  oldMobipocket(1),
  mobipocket(2);

  const EncryptionType(this.code);

  final int code;

  static EncryptionType fromCode(int code) {
    for (final e in EncryptionType.values) {
      if (e.code == code) return e;
    }
    throw HeaderException('unknown encryption code: $code');
  }
}

/// The 16-byte PalmDOC header sitting at the start of record 0.
///
/// This header tells us *how* the text records are compressed, *how many*
/// of them there are, and whether the file is encrypted. Everything else
/// (Mobi version, EXTH metadata, image indices) lives in the MOBI header
/// that immediately follows.
class PalmDocHeader {
  const PalmDocHeader({
    required this.compression,
    required this.textLength,
    required this.textRecordCount,
    required this.maxRecordSize,
    required this.encryption,
  });

  /// Size of the PalmDOC header in bytes. The MOBI header starts at this
  /// offset within record 0.
  static const int byteSize = 16;

  final CompressionType compression;

  /// Uncompressed length of the book text in bytes.
  final int textLength;

  /// Number of PalmDOC text records following record 0.
  final int textRecordCount;

  /// Maximum size of a single uncompressed text record. Almost always 4096.
  final int maxRecordSize;

  final EncryptionType encryption;

  bool get isEncrypted => encryption != EncryptionType.none;

  static PalmDocHeader parse(Uint8List record0) {
    if (record0.length < byteSize) {
      throw HeaderException(
        'record 0 too short for PalmDOC header: ${record0.length} < $byteSize',
      );
    }
    final view = ByteData.sublistView(record0, 0, byteSize);

    return PalmDocHeader(
      compression: CompressionType.fromCode(view.getUint16(0)),
      textLength: view.getUint32(4),
      textRecordCount: view.getUint16(8),
      maxRecordSize: view.getUint16(10),
      encryption: EncryptionType.fromCode(view.getUint16(12)),
    );
  }
}
