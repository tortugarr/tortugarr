import 'dart:convert';
import 'dart:typed_data';

import '../exception.dart';

/// Thrown when a HUFF/CDIC record can't be parsed or a compressed text
/// record can't be decoded.
class HuffCdicException extends KindleUnpackException {
  HuffCdicException(super.message);
}

/// One entry in the HUFF cache (the 256-entry table indexed by the top
/// 8 bits of the input). Real-world MOBI files carry these as packed
/// uint32s; we unpack into a typed record here for clarity.
class HuffCacheEntry {
  const HuffCacheEntry({
    required this.codeLen,
    required this.terminal,
    required this.maxCode,
  });

  /// Number of bits this code consumes (1..32).
  final int codeLen;

  /// True when the cache entry alone resolves the codeword. False means
  /// we still need to scan [HuffTable.minCode]/[HuffTable.maxCodeByLen]
  /// to find the actual length.
  final bool terminal;

  /// Pre-shifted maximum code value with this prefix, used to compute
  /// the dictionary index as `(maxCode - code) >>> (32 - codeLen)`.
  final int maxCode;
}

/// Parsed HUFF record. The body is two tables: a 256-entry cache for the
/// fast path, and a 32-pair (mincode, maxcode) table indexed by code
/// length 1..32 for the slow path on non-terminal cache hits.
class HuffTable {
  HuffTable._({
    required this.cache,
    required this.minCode,
    required this.maxCodeByLen,
  });

  /// 256 entries indexed by the top 8 bits of the input bitstream.
  final List<HuffCacheEntry> cache;

  /// Indexed by code length 0..32. `minCode[i]` is the smallest 32-bit
  /// code value that has length `i`. Index 0 is a sentinel.
  final List<int> minCode;

  /// Indexed by code length 0..32. `maxCodeByLen[i]` is the largest
  /// 32-bit code value with length `i` (inclusive).
  final List<int> maxCodeByLen;

  static HuffTable parse(Uint8List record) {
    if (record.length < 24) {
      throw HuffCdicException(
        'HUFF record too short: ${record.length} (need 24+ for header)',
      );
    }
    final view = ByteData.sublistView(record);

    // The signature includes the fixed header length (0x18 = 24).
    final sig = latin1.decode(Uint8List.sublistView(record, 0, 4));
    if (sig != 'HUFF') {
      throw HuffCdicException('expected "HUFF" signature, got "$sig"');
    }
    final headerLen = view.getUint32(4);
    if (headerLen != 0x18) {
      throw HuffCdicException(
        'unsupported HUFF header length: 0x${headerLen.toRadixString(16)}',
      );
    }

    final off1 = view.getUint32(8);
    final off2 = view.getUint32(12);
    if (off1 + 256 * 4 > record.length) {
      throw HuffCdicException(
        'HUFF cache table at offset $off1 extends past record end',
      );
    }
    if (off2 + 64 * 4 > record.length) {
      throw HuffCdicException(
        'HUFF mincode/maxcode table at offset $off2 extends past record end',
      );
    }

    final cache = List<HuffCacheEntry>.generate(256, (i) {
      final v = view.getUint32(off1 + i * 4);
      final codeLen = v & 0x1F;
      final terminal = (v & 0x80) != 0;
      final maxCodeRaw = v >> 8; // 24 bits
      if (codeLen == 0) {
        throw HuffCdicException('HUFF cache entry $i has codeLen 0');
      }
      if (codeLen <= 8 && !terminal) {
        throw HuffCdicException(
          'HUFF cache entry $i has codeLen $codeLen but is non-terminal',
        );
      }
      // Promote the 24-bit raw value to a 32-bit ceiling.
      final maxCode = ((maxCodeRaw + 1) << (32 - codeLen)) - 1;
      return HuffCacheEntry(
        codeLen: codeLen,
        terminal: terminal,
        maxCode: maxCode & 0xFFFFFFFF,
      );
    }, growable: false);

    // Build min/max-code arrays. Index 0 is sentinel; indices 1..32 hold
    // the (mincode, maxcode) for codes of that length.
    final minCode = List<int>.filled(33, 0);
    final maxCodeByLen = List<int>.filled(33, 0);
    // Length 0 sentinels: mincode=0, maxcode = ((0+1) << 32) - 1.
    // (Dart's int is 64-bit signed, so we just store 0xFFFFFFFF here.)
    maxCodeByLen[0] = 0xFFFFFFFF;
    for (var i = 1; i <= 32; i++) {
      final mincodeRaw = view.getUint32(off2 + (i - 1) * 8);
      final maxcodeRaw = view.getUint32(off2 + (i - 1) * 8 + 4);
      minCode[i] = (mincodeRaw << (32 - i)) & 0xFFFFFFFF;
      maxCodeByLen[i] = (((maxcodeRaw + 1) << (32 - i)) - 1) & 0xFFFFFFFF;
    }

    return HuffTable._(
      cache: cache,
      minCode: minCode,
      maxCodeByLen: maxCodeByLen,
    );
  }
}

/// One entry in the merged CDIC dictionary. [bytes] is either a
/// pre-decoded literal phrase ([precoded]=true) or itself a HUFF-encoded
/// payload that must be recursively expanded on first use.
class CdicEntry {
  CdicEntry({required this.bytes, required this.precoded});

  Uint8List bytes;
  bool precoded;
}

/// The merged dictionary built from one HUFF record's worth of CDIC
/// records (typically 1..a few). Index space matches the integers
/// produced by [decompressHuffCdic] when it resolves a codeword.
class CdicTable {
  CdicTable._({required this.entries, required this.codeBits});

  final List<CdicEntry> entries;

  /// Code length in bits (typically 16 — i.e. up to 65 536 entries per
  /// CDIC record). Stored mostly for diagnostics.
  final int codeBits;

  /// Build the dictionary from [records] in order. The first CDIC
  /// declares the total phrase count and the per-record bits; subsequent
  /// CDICs continue filling the same flat list.
  static CdicTable parse(List<Uint8List> records) {
    if (records.isEmpty) {
      throw HuffCdicException('CDIC table needs at least one record');
    }
    var totalPhrases = 0;
    var bits = 0;
    final entries = <CdicEntry>[];

    for (var ri = 0; ri < records.length; ri++) {
      final rec = records[ri];
      if (rec.length < 16) {
        throw HuffCdicException(
          'CDIC record $ri too short: ${rec.length} (need 16+)',
        );
      }
      final view = ByteData.sublistView(rec);
      final sig = latin1.decode(Uint8List.sublistView(rec, 0, 4));
      if (sig != 'CDIC') {
        throw HuffCdicException(
          'CDIC record $ri: expected "CDIC" signature, got "$sig"',
        );
      }
      final headerLen = view.getUint32(4);
      if (headerLen != 0x10) {
        throw HuffCdicException(
          'CDIC record $ri: unsupported header length '
          '0x${headerLen.toRadixString(16)}',
        );
      }
      final phrases = view.getUint32(8);
      final recBits = view.getUint32(12);
      if (ri == 0) {
        totalPhrases = phrases;
        bits = recBits;
      } else if (phrases != totalPhrases || recBits != bits) {
        throw HuffCdicException(
          'CDIC record $ri header disagrees with first record '
          '(phrases=$phrases vs $totalPhrases, bits=$recBits vs $bits)',
        );
      }
      // How many entries this record carries: at most 1<<bits, capped at
      // whatever's left to fill the totalPhrases budget.
      final n = (1 << bits).clamp(0, totalPhrases - entries.length);
      if (n == 0) break;
      // Offset table: n uint16 entries pointing into the record body.
      final tableEnd = 16 + n * 2;
      if (tableEnd > rec.length) {
        throw HuffCdicException(
          'CDIC record $ri offset table runs past record end',
        );
      }
      for (var i = 0; i < n; i++) {
        final off = view.getUint16(16 + i * 2);
        if (16 + off + 2 > rec.length) {
          throw HuffCdicException(
            'CDIC record $ri entry $i offset $off out of range',
          );
        }
        final lengthAndFlag = view.getUint16(16 + off);
        final blen = lengthAndFlag & 0x7FFF;
        final precoded = (lengthAndFlag & 0x8000) != 0;
        final start = 16 + off + 2;
        final end = start + blen;
        if (end > rec.length) {
          throw HuffCdicException(
            'CDIC record $ri entry $i payload runs past record end',
          );
        }
        entries.add(
          CdicEntry(
            bytes: Uint8List.sublistView(rec, start, end),
            precoded: precoded,
          ),
        );
      }
    }

    if (entries.length != totalPhrases) {
      throw HuffCdicException(
        'CDIC: filled ${entries.length} entries but header advertises '
        '$totalPhrases',
      );
    }
    return CdicTable._(entries: entries, codeBits: bits);
  }
}

/// Decompress a single HUFF/CDIC-compressed payload. Caches the result
/// of recursively expanded dictionary entries on the [cdic] in place
/// (precoded=true after first use), so subsequent records reuse the
/// work.
///
/// Algorithm port of `HuffcdicReader.unpack` from KindleUnpack
/// (mobi_uncompress.py). The 64-bit sliding window is maintained as two
/// big-endian uint32s so we don't depend on 64-bit unsigned semantics
/// the way the Python original does.
Uint8List decompressHuffCdic({
  required Uint8List input,
  required HuffTable huff,
  required CdicTable cdic,
}) {
  return _DecompressContext(huff, cdic).run(input);
}

class _DecompressContext {
  _DecompressContext(this.huff, this.cdic);

  final HuffTable huff;
  final CdicTable cdic;

  /// Cycle-detection set: dictionary indices currently being expanded.
  /// A precoded entry that recursively references itself would otherwise
  /// loop forever.
  final Set<int> _expanding = <int>{};

  Uint8List run(Uint8List input) {
    // Pad with 8 zero bytes so the 64-bit-window reads at the tail are
    // safe. Real text records are 4 KiB so this is cheap.
    final padded = Uint8List(input.length + 8);
    padded.setRange(0, input.length, input);
    final view = ByteData.sublistView(padded);

    var bitsLeft = input.length * 8;
    var pos = 0;
    var high = view.getUint32(0);
    var low = view.getUint32(4);
    var n = 32;

    final out = BytesBuilder(copy: false);

    while (true) {
      if (n <= 0) {
        pos += 4;
        high = low;
        low = view.getUint32(pos + 4);
        n += 32;
      }

      // code = top 32 bits of (high::low) shifted right by n.
      final int code;
      if (n == 32) {
        code = high;
      } else if (n == 0) {
        code = low;
      } else {
        code = ((high << (32 - n)) | (low >>> n)) & 0xFFFFFFFF;
      }

      final cacheEntry = huff.cache[code >>> 24];
      var codeLen = cacheEntry.codeLen;
      var maxCode = cacheEntry.maxCode;
      if (!cacheEntry.terminal) {
        while (code < huff.minCode[codeLen]) {
          codeLen++;
          if (codeLen > 32) {
            throw HuffCdicException('codeword exceeds 32 bits');
          }
        }
        maxCode = huff.maxCodeByLen[codeLen];
      }

      n -= codeLen;
      bitsLeft -= codeLen;
      if (bitsLeft < 0) break;

      final r = (maxCode - code) >>> (32 - codeLen);
      if (r < 0 || r >= cdic.entries.length) {
        throw HuffCdicException(
          'dictionary index $r out of range '
          '(table size ${cdic.entries.length})',
        );
      }
      final entry = cdic.entries[r];
      if (entry.precoded) {
        out.add(entry.bytes);
      } else {
        if (!_expanding.add(r)) {
          throw HuffCdicException('cycle in CDIC entry $r');
        }
        final expanded = run(entry.bytes);
        _expanding.remove(r);
        // Cache for subsequent records of the same book.
        entry.bytes = expanded;
        entry.precoded = true;
        out.add(expanded);
      }
    }

    return out.toBytes();
  }
}
