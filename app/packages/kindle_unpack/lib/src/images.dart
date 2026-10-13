import 'dart:typed_data';

import 'headers/exth.dart';
import 'headers/mobi_header.dart';
import 'pdb.dart';

/// Image formats embedded in MOBI / KF8 files, detected by magic bytes
/// at the start of the record. WebP and JPEG2000 do appear occasionally
/// in KF8 files; we add them as we hit them.
enum ImageFormat {
  jpeg('jpg', [0xFF, 0xD8, 0xFF]),
  png('png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
  gif('gif', [0x47, 0x49, 0x46, 0x38]), // matches GIF87a + GIF89a
  bmp('bmp', [0x42, 0x4D]),
  svg('svg', _svgMarker);

  const ImageFormat(this.extension, this.magic);

  /// File extension (without leading dot), e.g. "jpg".
  final String extension;

  /// Magic-byte prefix that identifies this format. SVG uses a sentinel
  /// (see [_svgMarker]) and is matched separately by [detect].
  final List<int> magic;

  /// Sniff the format of [bytes] from its leading magic. Returns null
  /// when the prefix doesn't match any known format.
  static ImageFormat? detect(Uint8List bytes) {
    for (final fmt in ImageFormat.values) {
      if (fmt == ImageFormat.svg) continue;
      if (_startsWith(bytes, fmt.magic)) return fmt;
    }
    if (_looksLikeSvg(bytes)) return ImageFormat.svg;
    return null;
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  /// SVG can show up as a raw `<svg ...>` document or as XML wrapping —
  /// `<?xml version=...?>` followed by an `<svg>` root. We check the
  /// first ~256 bytes for either signal so we don't accidentally
  /// classify e.g. the RESC record (also XML, but `<metadata>` rooted)
  /// as an image.
  static bool _looksLikeSvg(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final scanLen = bytes.length < 256 ? bytes.length : 256;
    // Lower-case '<svg' — case-insensitive match.
    for (var i = 0; i + 4 <= scanLen; i++) {
      final b0 = bytes[i];
      if (b0 != 0x3C) continue; // '<'
      final c1 = bytes[i + 1] | 0x20;
      final c2 = bytes[i + 2] | 0x20;
      final c3 = bytes[i + 3] | 0x20;
      if (c1 == 0x73 && c2 == 0x76 && c3 == 0x67) return true; // 'svg'
    }
    return false;
  }
}

// Sentinel — SVG matching is content-based via [ImageFormat._looksLikeSvg],
// not a fixed prefix. Using an unmatchable byte sequence keeps the regular
// `_startsWith` path from ever firing for SVG.
const List<int> _svgMarker = <int>[];

/// One image extracted from a MOBI's image record block.
class ExtractedImage {
  const ExtractedImage({
    required this.blockIndex,
    required this.recordIndex,
    required this.format,
    required this.data,
  });

  /// 0-based index within the image block (= [recordIndex] minus the
  /// MOBI header's `firstImageIndex`). EXTH 201 (cover) and 202
  /// (thumbnail) point at this index.
  final int blockIndex;

  /// PDB record index this image was sliced from.
  final int recordIndex;

  final ImageFormat format;
  final Uint8List data;

  /// File-system-friendly name following KindleUnpack's convention,
  /// e.g. `image00007.jpg`. The 5-digit width matches the maximum image
  /// count any real MOBI file is going to have.
  String get name =>
      'image${blockIndex.toString().padLeft(5, '0')}.${format.extension}';
}

/// All images in a MOBI book plus the cover/thumbnail pointers from
/// EXTH. Construct via [BookImages.extract].
class BookImages {
  const BookImages({
    required this.all,
    required this.coverBlockIndex,
    required this.thumbnailBlockIndex,
  });

  final List<ExtractedImage> all;

  /// Raw EXTH 201 value, or null if the file didn't set one. Note that
  /// this index doesn't have to point at a record we recognised as an
  /// image — KF8 books occasionally store the cover at a non-image
  /// resource record.
  final int? coverBlockIndex;
  final int? thumbnailBlockIndex;

  ExtractedImage? get cover => _findByBlockIndex(coverBlockIndex);
  ExtractedImage? get thumbnail => _findByBlockIndex(thumbnailBlockIndex);

  /// Map from generated image filename to bytes — convenient for
  /// serialising to disk or wiring into the EPUB packager (Phase 10).
  Map<String, Uint8List> toMap() => {
        for (final img in all) img.name: img.data,
      };

  ExtractedImage? _findByBlockIndex(int? idx) {
    if (idx == null) return null;
    for (final img in all) {
      if (img.blockIndex == idx) return img;
    }
    return null;
  }

  /// Walk PDB records starting at [MobiHeader.firstImageIndex], sniff
  /// each one, and collect everything that looks like a known image
  /// format. Records with unrecognised magic (FONT/RESC/INDX in KF8,
  /// trailing markers, etc.) are silently skipped — they keep their
  /// slot in the block-index numbering, so EXTH cover/thumbnail offsets
  /// continue to line up.
  static BookImages extract({
    required PdbFile pdb,
    required MobiHeader mobi,
    ExthHeader? exth,
  }) {
    final firstImage = mobi.firstImageIndex;
    final coverIdx = exth?.coverOffset;
    final thumbIdx = exth?.thumbnailOffset;

    if (firstImage == MobiHeader.unset ||
        firstImage == 0 ||
        firstImage >= pdb.records.length) {
      return BookImages(
        all: const [],
        coverBlockIndex: coverIdx,
        thumbnailBlockIndex: thumbIdx,
      );
    }

    final images = <ExtractedImage>[];
    for (var i = firstImage; i < pdb.records.length; i++) {
      final data = pdb.records[i].data;
      final fmt = ImageFormat.detect(data);
      if (fmt == null) continue;
      images.add(
        ExtractedImage(
          blockIndex: i - firstImage,
          recordIndex: i,
          format: fmt,
          data: data,
        ),
      );
    }

    return BookImages(
      all: List.unmodifiable(images),
      coverBlockIndex: coverIdx,
      thumbnailBlockIndex: thumbIdx,
    );
  }
}
