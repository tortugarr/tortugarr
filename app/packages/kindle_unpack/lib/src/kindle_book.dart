import 'dart:typed_data';

import 'decompress/book_text.dart';
import 'epub.dart';
import 'headers/exth.dart';
import 'headers/header_exception.dart';
import 'headers/mobi_header.dart';
import 'headers/palmdoc_header.dart';
import 'images.dart';
import 'kf8/boundary.dart';
import 'kf8/fdst.dart';
import 'kf8/flows.dart';
import 'kf8/font.dart';
import 'kf8/skeleton_fragment.dart';
import 'kf8/xhtml_split.dart';
import 'pdb.dart';

/// One-shot parser that ties Phases 1–10b together. `KindleBook.fromBytes`
/// runs the full pipeline (PDB → headers → EXTH → text decompression →
/// flow split → XHTML splice → image extraction) and exposes the
/// intermediate results plus a `toEpub()` convenience.
///
/// This is the public-API target sketched in the README. It's
/// intentionally a thin coordinator; every interesting algorithm still
/// lives in the underlying typed parser.
class KindleBook {
  KindleBook._({
    required this.pdb,
    required this.format,
    required this.section,
    required this.rawML,
    required this.parts,
    required this.images,
    required this.flows,
    required this.fonts,
  });

  factory KindleBook.fromBytes(Uint8List bytes) {
    final pdb = PdbFile.parse(bytes);
    final kf = KindleFile.inspect(pdb);
    final section = kf.kf8 ?? kf.mobi7!;
    final rawML = decompressBookText(
      pdb: pdb,
      palmDoc: section.palmDoc,
      mobi: section.mobi,
    );

    BookFlows? flows;
    List<XhtmlPart> parts;
    if (kf.kf8 != null) {
      // KF8 path: split into flows + splice into XHTML parts.
      final fdstRecIdx =
          section.mobi.fdstRecord! + section.recordOffset;
      final fdst = FdstTable.parse(pdb.records[fdstRecIdx].data);
      flows = BookFlows.split(rawML, fdst);
      try {
        final skel = SkeletonTable.parse(pdb, section.mobi);
        final frag = FragmentTable.parse(pdb, section.mobi);
        parts = XhtmlSplitter.split(
          primaryFlow: flows.primaryHtml!.bytes,
          skeletons: skel,
          fragments: frag,
        );
      } on HeaderException {
        // Some KF8 files don't have full skeleton/fragment INDX (rare,
        // typically Print Replica or scrambled). Fall back to a single
        // monolithic part so we still produce a valid EPUB.
        parts = [
          XhtmlPart(fileNumber: 0, bytes: flows.primaryHtml!.bytes),
        ];
      }
    } else {
      // Mobi-7 path: rawML is one self-contained HTML blob; emit a
      // single part.
      parts = [XhtmlPart(fileNumber: 0, bytes: rawML)];
    }

    final images = BookImages.extract(
      pdb: pdb,
      mobi: section.mobi,
      exth: section.exth,
    );

    final fonts = _extractFonts(pdb, section);

    return KindleBook._(
      pdb: pdb,
      format: kf.format,
      section: section,
      rawML: rawML,
      parts: parts,
      images: images,
      flows: flows,
      fonts: fonts,
    );
  }

  static List<FontResource> _extractFonts(PdbFile pdb, KindleSection section) {
    final fonts = <FontResource>[];
    final start = section.mobi.firstImageIndex;
    if (start == MobiHeader.unset || start == 0) return fonts;
    for (var i = start; i < pdb.records.length; i++) {
      final d = pdb.records[i].data;
      if (d.length >= 4 &&
          d[0] == 0x46 && d[1] == 0x4F && d[2] == 0x4E && d[3] == 0x54) {
        try {
          fonts.add(FontResource.parse(d));
        } on HeaderException {
          // Skip records that look like FONT but don't parse — corrupt
          // entries shouldn't bring down the whole book.
        }
      }
    }
    return fonts;
  }

  final PdbFile pdb;
  final KindleFormat format;
  final KindleSection section;

  /// The decompressed text body. For KF8 this is the full rawML (HTML +
  /// CSS + auxiliary flows concatenated); for Mobi-7 it's the full HTML.
  final Uint8List rawML;

  /// XHTML parts produced by [XhtmlSplitter] (KF8) or a single
  /// monolithic part (Mobi-7).
  final List<XhtmlPart> parts;
  final BookImages images;

  /// Non-null only for KF8 books — null on Mobi-7-only files.
  final BookFlows? flows;

  /// Embedded fonts decoded from FONT records (Phase 8). Empty list when
  /// the book ships none — the common case for novels.
  final List<FontResource> fonts;

  ExthHeader? get exth => section.exth;
  PalmDocHeader get palmDoc => section.palmDoc;
  MobiHeader get mobi => section.mobi;

  /// Best-effort book title — EXTH 503 if present, else the MOBI
  /// header's `fullName`.
  String get title {
    return exth?.title ??
        section.mobi.fullName(pdb.records[section.recordOffset].data);
  }

  /// Package this book as an EPUB 3 zip. Other-flow data (CSS, etc.) is
  /// emitted as `style0001.css` etc. so the parts that link to it
  /// resolve cleanly inside the zip.
  Uint8List toEpub() {
    final css = <EpubAsset>[];
    if (flows != null) {
      var i = 1;
      for (final f in flows!.flows) {
        if (f.kind == FlowKind.css) {
          css.add(EpubAsset(
            name: 'style${i.toString().padLeft(4, '0')}.css',
            bytes: f.bytes,
          ));
          i++;
        }
      }
    }

    final fontAssets = <EpubAsset>[];
    for (var i = 0; i < fonts.length; i++) {
      final font = fonts[i];
      fontAssets.add(EpubAsset(
        name: 'font${i.toString().padLeft(4, '0')}.${font.format.extension}',
        bytes: font.payload,
        mediaType: _fontMime(font.format),
      ));
    }

    final cover = images.cover;
    final coverId = cover != null ? 'img${cover.blockIndex}' : null;

    final metadata = EpubMetadata(
      identifier: exth?.asin ?? 'urn:kindle:${mobi.uniqueId}',
      title: title,
      language: exth?.language ?? 'und',
      creators: exth?.authors ?? const [],
      publisher: exth?.publisher,
      description: exth?.description,
      coverImageId: coverId,
    );

    return EpubBuilder.build(
      metadata: metadata,
      parts: parts,
      images: images.all,
      css: css,
      fonts: fontAssets,
    );
  }

  static String? _fontMime(FontFormat fmt) {
    switch (fmt) {
      case FontFormat.ttf:
        return 'application/font-sfnt';
      case FontFormat.ttc:
        return 'application/font-sfnt';
      case FontFormat.otf:
        return 'application/vnd.ms-opentype';
      case FontFormat.unknown:
        return null;
    }
  }
}
