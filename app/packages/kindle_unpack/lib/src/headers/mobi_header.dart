import 'dart:convert';
import 'dart:typed_data';

import 'header_exception.dart';
import 'palmdoc_header.dart';

/// The variable-length MOBI header that follows the 16-byte PalmDOC header.
///
/// Field offsets are quoted relative to the start of the MOBI signature
/// (i.e. record-0 offset [PalmDocHeader.byteSize]). The header's declared
/// [headerLength] determines which fields are present; trailing fields
/// missing from a short header are reported as `null` rather than read from
/// whatever happens to follow (often EXTH bytes).
class MobiHeader {
  const MobiHeader({
    required this.headerLength,
    required this.mobiType,
    required this.textEncoding,
    required this.uniqueId,
    required this.fileVersion,
    required this.firstNonBookIndex,
    required this.fullNameOffset,
    required this.fullNameLength,
    required this.locale,
    required this.inputLanguage,
    required this.outputLanguage,
    required this.minVersion,
    required this.firstImageIndex,
    required this.huffmanRecordOffset,
    required this.huffmanRecordCount,
    required this.huffmanTableOffset,
    required this.huffmanTableLength,
    required this.exthFlags,
    required this.drmOffset,
    required this.drmCount,
    required this.drmSize,
    required this.drmFlags,
    required this.fdstRecord,
    required this.fdstFlowCount,
    required this.fragmentIndex,
    required this.skeletonIndex,
    required this.extraDataFlags,
  });

  /// 4-byte signature at the start of the MOBI header.
  static const String signature = 'MOBI';

  /// Sentinel meaning "field unset" in 32-bit MOBI fields.
  static const int unset = 0xFFFFFFFF;

  /// Length of the MOBI header in bytes (including the 4-byte signature
  /// and this field itself).
  final int headerLength;

  /// Mobi document type. 2 = Mobipocket book, 3 = PalmDOC book, 257 = News,
  /// etc. We store the raw int — downstream code can decide what to allow.
  final int mobiType;

  /// Codepage of textual fields in this header and of the book text:
  /// 1252 = Windows-1252, 65001 = UTF-8.
  final int textEncoding;

  final int uniqueId;
  final int fileVersion;

  /// Record index of the first non-book record (indexes, etc.).
  final int firstNonBookIndex;

  /// Byte offset of the human-readable book title within record 0.
  final int fullNameOffset;
  final int fullNameLength;

  /// Numeric locale code. 9 = English, etc. See MobiPerl docs.
  final int locale;
  final int inputLanguage;
  final int outputLanguage;
  final int minVersion;

  /// Record index of the first image record (or [unset]).
  final int firstImageIndex;

  /// HUFF/CDIC compression: index of the first HUFF record and count of
  /// HUFF/CDIC records that follow it.
  final int huffmanRecordOffset;
  final int huffmanRecordCount;
  final int huffmanTableOffset;
  final int huffmanTableLength;

  /// Bitfield: bit 0x40 set means an EXTH header follows the MOBI header.
  final int exthFlags;

  /// DRM section. All four fields are absent in old / short MOBI headers,
  /// and in newer ones [drmOffset] = [unset] means "no DRM".
  final int? drmOffset;
  final int? drmCount;
  final int? drmSize;
  final int? drmFlags;

  /// PDB record index of the FDST table on KF8 headers ([fileVersion] >=
  /// 8). On Mobi-7 headers the same offset (rel 176) holds the
  /// `first_content` record instead — readers should consult
  /// [fileVersion] before treating this as an FDST pointer. Null only
  /// when [headerLength] doesn't reach this field.
  final int? fdstRecord;

  /// KF8-only: count of "flows" the FDST splits the rawML into. The FDST
  /// table itself carries the per-flow byte ranges. Garbage on Mobi-7
  /// headers — same offset (rel 180) holds an unrelated value there.
  final int? fdstFlowCount;

  /// KF8-only: PDB record index of the fragment INDX (per-fragment ID
  /// metadata, used to reassemble HTML chunks). [unset] if absent.
  final int? fragmentIndex;

  /// KF8-only: PDB record index of the skeleton INDX (the HTML skeleton
  /// into which fragments are spliced). [unset] if absent.
  final int? skeletonIndex;

  /// Bitfield at MOBI offset 0xF2 (uint16) describing per-text-record
  /// trailing data entries. Bit `i > 0` set means each compressed text
  /// record has a length-prefixed trailer for category `i` appended at
  /// its end. Bit 0 set means each record ends with a single byte whose
  /// low 2 bits + 1 give the count of bytes that overlap with the next
  /// record's first multi-byte char. Older MOBI headers don't include
  /// this field — we report it as 0 there, which means "no trailers".
  final int extraDataFlags;

  /// True if an EXTH header sits immediately after this MOBI header.
  bool get hasExth => (exthFlags & 0x40) != 0;

  /// True if the MOBI header advertises a DRM section with at least one
  /// entry. This signals the file is encrypted; this library cannot parse
  /// the text body.
  bool get hasDrm {
    final off = drmOffset;
    final count = drmCount;
    if (off == null || count == null) return false;
    if (off == unset || count == unset) return false;
    return count > 0;
  }

  /// Byte offset within record 0 where the EXTH header begins (whether or
  /// not [hasExth] is true).
  int get exthOffset => PalmDocHeader.byteSize + headerLength;

  /// Best-effort decode of the book's full title from record 0. Uses UTF-8
  /// when [textEncoding] is 65001, otherwise latin1 (a close-enough stand-in
  /// for Windows-1252; a strict decoder can be added later).
  String fullName(Uint8List record0) {
    if (fullNameLength == 0) return '';
    final end = fullNameOffset + fullNameLength;
    if (end > record0.length) {
      throw HeaderException(
        'full name [$fullNameOffset, $end) extends past record 0 '
        '(${record0.length})',
      );
    }
    final slice = Uint8List.sublistView(record0, fullNameOffset, end);
    return textEncoding == 65001
        ? utf8.decode(slice, allowMalformed: true)
        : latin1.decode(slice);
  }

  static MobiHeader parse(Uint8List record0) {
    const sigOffset = PalmDocHeader.byteSize;
    if (record0.length < sigOffset + 8) {
      throw HeaderException(
        'record 0 too short for MOBI signature + length: ${record0.length}',
      );
    }
    final view = ByteData.sublistView(record0);

    final sig = latin1.decode(
      Uint8List.sublistView(record0, sigOffset, sigOffset + 4),
    );
    if (sig != signature) {
      throw HeaderException('expected "$signature" signature, got "$sig"');
    }

    final headerLength = view.getUint32(sigOffset + 4);
    if (headerLength < 24) {
      throw HeaderException(
        'MOBI header length too small: $headerLength (need >= 24)',
      );
    }
    if (sigOffset + headerLength > record0.length) {
      throw HeaderException(
        'MOBI header (length $headerLength) extends past record 0 '
        '(${record0.length})',
      );
    }

    /// Read a uint32 at [relOffset] inside the MOBI header. Returns null
    /// when the declared [headerLength] doesn't reach this field — those
    /// bytes belong to whatever follows (typically EXTH) and are not ours
    /// to interpret.
    int? readU32(int relOffset) {
      if (relOffset + 4 > headerLength) return null;
      return view.getUint32(sigOffset + relOffset);
    }

    int? readU16(int relOffset) {
      if (relOffset + 2 > headerLength) return null;
      return view.getUint16(sigOffset + relOffset);
    }

    // MOBI field offsets are relative to the "MOBI" signature itself
    // (see https://wiki.mobileread.com/wiki/MOBI). The fixed-size index
    // block (orthographic, inflection, names, keys, extra 0..5) occupies
    // offsets 24..63, then the per-book fields start at 64.
    return MobiHeader(
      headerLength: headerLength,
      mobiType: readU32(8) ?? 0,
      textEncoding: readU32(12) ?? 0,
      uniqueId: readU32(16) ?? 0,
      fileVersion: readU32(20) ?? 0,
      firstNonBookIndex: readU32(64) ?? unset,
      fullNameOffset: readU32(68) ?? 0,
      fullNameLength: readU32(72) ?? 0,
      locale: readU32(76) ?? 0,
      inputLanguage: readU32(80) ?? 0,
      outputLanguage: readU32(84) ?? 0,
      minVersion: readU32(88) ?? 0,
      firstImageIndex: readU32(92) ?? unset,
      huffmanRecordOffset: readU32(96) ?? 0,
      huffmanRecordCount: readU32(100) ?? 0,
      huffmanTableOffset: readU32(104) ?? 0,
      huffmanTableLength: readU32(108) ?? 0,
      exthFlags: readU32(112) ?? 0,
      // DRM block: per KindleUnpack's mobi_header.py, the four DRM fields
      // sit at MOBI-relative 152..167. Earlier versions of this parser had
      // them at 148..163, which lined up with `unknown0` + drm_offset +
      // drm_count + drm_size — the bug stayed hidden because every fixture
      // we had carried 0xFFFFFFFF in `unknown0` (so drmOffset still read as
      // unset and hasDrm still returned false).
      drmOffset: readU32(152),
      drmCount: readU32(156),
      drmSize: readU32(160),
      drmFlags: readU32(164),
      fdstRecord: readU32(176),
      fdstFlowCount: readU32(180),
      fragmentIndex: readU32(232),
      skeletonIndex: readU32(236),
      extraDataFlags: readU16(226) ?? 0,
    );
  }
}
