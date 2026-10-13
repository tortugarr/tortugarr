import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import '../headers/header_exception.dart';

/// Container format for a font file embedded in a KF8 record.
enum FontFormat {
  /// TrueType, identified by the `\x00\x01\x00\x00` or `true` header.
  ttf('ttf'),

  /// TrueType collection, identified by the `ttcf` header.
  ttc('ttf'),

  /// OpenType, identified by the `OTTO` header.
  otf('otf'),

  /// Header didn't match any known font signature. The bytes are still
  /// returned so the caller can save them as `.dat` and inspect.
  unknown('dat');

  const FontFormat(this.extension);

  /// File extension (without leading dot).
  final String extension;
}

/// One embedded font extracted from a KF8 FONT record.
///
/// Record layout (per KindleUnpack `kindleunpack.py:processFONT`):
///
/// ```
///   "FONT"             4 bytes signature
///   uint32 BE          uncompressed font size (informational)
///   uint32 BE          flags
///                        bit 0x0001: zlib-compressed payload
///                        bit 0x0002: XOR-obfuscated payload
///   uint32 BE          dataOffset — start of payload bytes within record
///   uint32 BE          xorKeyLength
///   uint32 BE          xorKeyOffset (within record)
///   ...                payload bytes from dataOffset to record end
/// ```
///
/// XOR deobfuscation cycles the key over the first **1040 bytes only**
/// (or fewer, if the payload is shorter). This matches the Adobe-style
/// OTF / TTF obfuscation Amazon adopted: only the font header is
/// scrambled to make the file unrecognisable to standard tooling.
class FontResource {
  FontResource._({
    required this.uncompressedSize,
    required this.flags,
    required this.payload,
    required this.xorKey,
    required this.format,
  });

  static const String signature = 'FONT';
  static const int flagZlib = 0x0001;
  static const int flagObfuscated = 0x0002;
  static const int _xorExtent = 1040;

  /// Declared uncompressed font size from the FONT header. May not match
  /// the actual decoded size on broken / hand-tampered files.
  final int uncompressedSize;

  /// Raw flags bitfield from the FONT header. Use [hasZlib] / [hasXor]
  /// instead unless you specifically need the raw value.
  final int flags;

  /// The payload bytes — already deobfuscated and (if needed) zlib
  /// decompressed. This is the actual TTF / OTF / etc. file content.
  final Uint8List payload;

  /// Raw XOR key from the record. Empty when the record had no key.
  /// Exposed mostly for diagnostics; consumers usually want [payload].
  final Uint8List xorKey;

  /// Best-effort format detection from the decoded [payload]'s first
  /// 4 bytes.
  final FontFormat format;

  bool get hasZlib => (flags & flagZlib) != 0;
  bool get hasXor => (flags & flagObfuscated) != 0;

  static FontResource parse(Uint8List record) {
    if (record.length < 24) {
      throw HeaderException(
        'FONT record too short: ${record.length} (need 24+ for header)',
      );
    }
    final sig = latin1.decode(Uint8List.sublistView(record, 0, 4));
    if (sig != signature) {
      throw HeaderException('expected "$signature" signature, got "$sig"');
    }
    final view = ByteData.sublistView(record);
    final usize = view.getUint32(4);
    final fflags = view.getUint32(8);
    final dStart = view.getUint32(12);
    final xorLen = view.getUint32(16);
    final xorStart = view.getUint32(20);

    if (dStart > record.length) {
      throw HeaderException(
        'FONT data offset $dStart is past record end (${record.length})',
      );
    }
    if (xorLen != 0 && xorStart + xorLen > record.length) {
      throw HeaderException(
        'FONT XOR key [$xorStart, ${xorStart + xorLen}) is past record end '
        '(${record.length})',
      );
    }

    final xorKey = xorLen == 0
        ? Uint8List(0)
        : Uint8List.sublistView(record, xorStart, xorStart + xorLen);

    // Copy out so we can mutate during deobfuscation without touching
    // the input buffer.
    var payload = Uint8List.fromList(
      Uint8List.sublistView(record, dStart, record.length),
    );

    if ((fflags & flagObfuscated) != 0) {
      if (xorKey.isEmpty) {
        throw HeaderException(
          'FONT marked obfuscated but no XOR key supplied',
        );
      }
      final extent = payload.length < _xorExtent ? payload.length : _xorExtent;
      for (var i = 0; i < extent; i++) {
        payload[i] ^= xorKey[i % xorKey.length];
      }
    }

    if ((fflags & flagZlib) != 0) {
      payload = Uint8List.fromList(ZLibCodec().decode(payload));
    }

    return FontResource._(
      uncompressedSize: usize,
      flags: fflags,
      payload: payload,
      xorKey: xorKey,
      format: _sniffFormat(payload),
    );
  }

  static FontFormat _sniffFormat(Uint8List payload) {
    if (payload.length < 4) return FontFormat.unknown;
    final h = payload;
    if (h[0] == 0x00 && h[1] == 0x01 && h[2] == 0x00 && h[3] == 0x00) {
      return FontFormat.ttf;
    }
    if (_eq4(h, 'true')) return FontFormat.ttf;
    if (_eq4(h, 'ttcf')) return FontFormat.ttc;
    if (_eq4(h, 'OTTO')) return FontFormat.otf;
    return FontFormat.unknown;
  }

  static bool _eq4(Uint8List bytes, String s) =>
      bytes[0] == s.codeUnitAt(0) &&
      bytes[1] == s.codeUnitAt(1) &&
      bytes[2] == s.codeUnitAt(2) &&
      bytes[3] == s.codeUnitAt(3);
}
