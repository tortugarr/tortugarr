import 'dart:convert';
import 'dart:typed_data';

import '../headers/header_exception.dart';

/// The RESC record in a KF8 file carries the OPF manifest XML — package
/// metadata, manifest of files, spine order, guide entries — that an
/// EPUB packager needs to reconstruct the book's structure.
///
/// On disk a RESC record looks like:
///
/// ```
///   "RESC"                    4 bytes signature
///   uint32 BE                 fixed header field (typically 0x10)
///   uint32 BE                 version (typically 1)
///   uint32 BE                 length of the URL-encoded preamble
///   N bytes                   preamble like `size=46O&version=1&type=1`
///                             (the `size=` value is base32-encoded and
///                             gives the XML payload length)
///   < ... > XML ... < /... >  the actual OPF XML
///   trailing nulls            (sometimes; not always)
/// ```
///
/// Phase 8's needs are modest — we just want the XML payload. The
/// preamble's encoded length is informational; we trust the bytes that
/// run from the first `<` until the last non-null byte of the record.
class RescResource {
  const RescResource({required this.xmlBytes});

  static const String signature = 'RESC';

  /// Raw bytes of the OPF XML, in the file's text encoding (UTF-8 in
  /// every KF8 file we've seen).
  final Uint8List xmlBytes;

  /// UTF-8 decode of [xmlBytes], with malformed sequences replaced.
  String get xml => utf8.decode(xmlBytes, allowMalformed: true);

  static RescResource parse(Uint8List record) {
    if (record.length < 4) {
      throw HeaderException(
        'RESC record too short: ${record.length} (need 4+ for signature)',
      );
    }
    final sig = latin1.decode(Uint8List.sublistView(record, 0, 4));
    if (sig != signature) {
      throw HeaderException('expected "$signature" signature, got "$sig"');
    }
    // Find the first '<' — that's where the XML payload begins. Real
    // RESC records have a preamble like "size=46O&version=1&type=1"
    // between the binary header and the XML; the exact length is
    // declared in the preamble itself and isn't worth re-deriving here.
    final ltIdx = record.indexOf(0x3C, 4);
    if (ltIdx < 0) {
      throw HeaderException('RESC record has no XML payload');
    }
    // Trim trailing null padding (KF8 files sometimes pad to a 4-byte
    // boundary).
    var end = record.length;
    while (end > ltIdx && record[end - 1] == 0) {
      end--;
    }
    return RescResource(
      xmlBytes: Uint8List.sublistView(record, ltIdx, end),
    );
  }
}
