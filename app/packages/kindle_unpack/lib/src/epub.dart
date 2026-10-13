import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'images.dart';
import 'kf8/xhtml_split.dart';

/// Minimal EPUB-3 builder: takes the building blocks Phases 5–10b
/// produced (XHTML parts, images, optional CSS / fonts) plus a small
/// metadata bundle, and emits a valid \[EPUB 3.x\] zip suitable for any
/// EPUB reader. The packager isn't ambitious — it doesn't try to
/// preserve Kindlegen's original spine ordering refinements or NCX
/// playOrder, just produces an EPUB that opens.
class EpubBuilder {
  EpubBuilder._();

  /// Build the EPUB zip. Returns the byte buffer (not written to disk).
  ///
  /// Layout matches the EPUB OCF spec:
  /// ```
  ///   mimetype                       (uncompressed, must be first)
  ///   META-INF/container.xml
  ///   OEBPS/content.opf
  ///   OEBPS/nav.xhtml
  ///   OEBPS/toc.ncx
  ///   OEBPS/Text/<part>.xhtml
  ///   OEBPS/Images/<image>.<ext>
  ///   OEBPS/Styles/<style>.css
  ///   OEBPS/Fonts/<font>.<ext>
  /// ```
  static Uint8List build({
    required EpubMetadata metadata,
    required List<XhtmlPart> parts,
    List<ExtractedImage> images = const [],
    List<EpubAsset> css = const [],
    List<EpubAsset> fonts = const [],
  }) {
    final archive = Archive();

    // 1) mimetype — uncompressed, no extra fields, MUST be first.
    final mimetype = ArchiveFile(
      'mimetype',
      _epubMimetype.length,
      Uint8List.fromList(_epubMimetype.codeUnits),
    )..compression = CompressionType.none;
    archive.addFile(mimetype);

    // 2) META-INF/container.xml
    _addUtf8(archive, 'META-INF/container.xml', _containerXml);

    // 3) OEBPS/content.opf
    _addUtf8(
      archive,
      'OEBPS/content.opf',
      _buildOpf(metadata, parts, images, css, fonts),
    );

    // 4) OEBPS/nav.xhtml (EPUB 3 nav doc — required by strict readers
    //    like epubx; the manifest item carries properties="nav").
    _addUtf8(
      archive,
      'OEBPS/nav.xhtml',
      _buildNav(metadata, parts),
    );

    // 5) OEBPS/toc.ncx (EPUB 2 fallback; readers happy with both)
    _addUtf8(
      archive,
      'OEBPS/toc.ncx',
      _buildNcx(metadata, parts),
    );

    // 5) Resources.
    for (final part in parts) {
      archive.addFile(
        ArchiveFile('OEBPS/Text/${part.filename}', part.bytes.length, part.bytes),
      );
    }
    for (final img in images) {
      archive.addFile(
        ArchiveFile('OEBPS/Images/${img.name}', img.data.length, img.data),
      );
    }
    for (final asset in css) {
      archive.addFile(
        ArchiveFile(
          'OEBPS/Styles/${asset.name}',
          asset.bytes.length,
          asset.bytes,
        ),
      );
    }
    for (final asset in fonts) {
      archive.addFile(
        ArchiveFile('OEBPS/Fonts/${asset.name}', asset.bytes.length, asset.bytes),
      );
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static void _addUtf8(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static String _buildOpf(
    EpubMetadata m,
    List<XhtmlPart> parts,
    List<ExtractedImage> images,
    List<EpubAsset> css,
    List<EpubAsset> fonts,
  ) {
    String esc(String s) => _escapeXml(s);
    final manifest = StringBuffer();
    final spine = StringBuffer();

    // Spine items — XHTML parts in declaration order.
    for (final p in parts) {
      final id = 'p${p.fileNumber}';
      manifest.writeln(
          '    <item id="$id" href="Text/${p.filename}" media-type="application/xhtml+xml"/>');
      spine.writeln('    <itemref idref="$id"/>');
    }
    for (final img in images) {
      final id = 'img${img.blockIndex}';
      manifest.writeln(
          '    <item id="$id" href="Images/${img.name}" media-type="${_imageMime(img.format)}"/>');
    }
    for (var i = 0; i < css.length; i++) {
      manifest.writeln(
          '    <item id="css$i" href="Styles/${css[i].name}" media-type="text/css"/>');
    }
    for (var i = 0; i < fonts.length; i++) {
      final mime = fonts[i].mediaType ?? 'application/octet-stream';
      manifest.writeln(
          '    <item id="font$i" href="Fonts/${fonts[i].name}" media-type="$mime"/>');
    }
    // EPUB 3 nav doc — strict readers (e.g. epubx) require an item
    // with properties="nav" or they fail to locate the TOC.
    manifest.writeln(
        '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>');
    // NCX item (referenced by spine via toc=).
    manifest.writeln(
        '    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>');

    final coverMeta = m.coverImageId != null
        ? '    <meta name="cover" content="${esc(m.coverImageId!)}"/>\n'
        : '';

    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="bookid">\n'
        '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '    <dc:identifier id="bookid">${esc(m.identifier)}</dc:identifier>\n'
        '    <dc:title>${esc(m.title)}</dc:title>\n'
        '    <dc:language>${esc(m.language)}</dc:language>\n'
        '${m.creators.map((c) => '    <dc:creator>${esc(c)}</dc:creator>\n').join()}'
        '${m.publisher == null ? '' : '    <dc:publisher>${esc(m.publisher!)}</dc:publisher>\n'}'
        '${m.description == null ? '' : '    <dc:description>${esc(m.description!)}</dc:description>\n'}'
        '$coverMeta'
        '  </metadata>\n'
        '  <manifest>\n'
        '$manifest'
        '  </manifest>\n'
        '  <spine toc="ncx">\n'
        '$spine'
        '  </spine>\n'
        '</package>\n';
  }

  static String _buildNav(EpubMetadata m, List<XhtmlPart> parts) {
    String esc(String s) => _escapeXml(s);
    final items = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      items.writeln(
          '        <li><a href="Text/${parts[i].filename}">Part ${i + 1}</a></li>');
    }
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="${esc(m.language)}">\n'
        '  <head>\n'
        '    <meta charset="utf-8"/>\n'
        '    <title>${esc(m.title)}</title>\n'
        '  </head>\n'
        '  <body>\n'
        '    <nav epub:type="toc" id="toc">\n'
        '      <h1>${esc(m.title)}</h1>\n'
        '      <ol>\n'
        '$items'
        '      </ol>\n'
        '    </nav>\n'
        '  </body>\n'
        '</html>\n';
  }

  static String _buildNcx(EpubMetadata m, List<XhtmlPart> parts) {
    String esc(String s) => _escapeXml(s);
    final navPoints = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      navPoints.writeln(
          '    <navPoint id="navPoint-${i + 1}" playOrder="${i + 1}">\n'
          '      <navLabel><text>Part ${i + 1}</text></navLabel>\n'
          '      <content src="Text/${p.filename}"/>\n'
          '    </navPoint>');
    }
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">\n'
        '  <head>\n'
        '    <meta name="dtb:uid" content="${esc(m.identifier)}"/>\n'
        '  </head>\n'
        '  <docTitle><text>${esc(m.title)}</text></docTitle>\n'
        '  <navMap>\n'
        '$navPoints'
        '  </navMap>\n'
        '</ncx>\n';
  }

  static String _imageMime(ImageFormat fmt) {
    switch (fmt) {
      case ImageFormat.jpeg:
        return 'image/jpeg';
      case ImageFormat.png:
        return 'image/png';
      case ImageFormat.gif:
        return 'image/gif';
      case ImageFormat.bmp:
        return 'image/bmp';
      case ImageFormat.svg:
        return 'image/svg+xml';
    }
  }

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Bundle of metadata the OPF + NCX need. Use the convenience
/// constructor [EpubMetadata.fromExth] when you already have a parsed
/// MOBI file — it pulls the fields straight from EXTH.
class EpubMetadata {
  const EpubMetadata({
    required this.identifier,
    required this.title,
    required this.language,
    this.creators = const [],
    this.publisher,
    this.description,
    this.coverImageId,
  });

  /// Unique book ID (ASIN, ISBN, or a generated UUID).
  final String identifier;
  final String title;

  /// IETF language tag, e.g. `en` or `en-us`. Defaults to `und`
  /// (undefined) when the source MOBI didn't carry a language.
  final String language;
  final List<String> creators;
  final String? publisher;
  final String? description;

  /// OPF manifest item id for the cover image (e.g. `img0`). Optional.
  final String? coverImageId;
}

/// One non-XHTML asset (CSS or font) to embed in the EPUB. Naming and
/// optional MIME type are caller-controlled so we don't have to decide
/// the EPUB's directory layout for fonts here.
class EpubAsset {
  const EpubAsset({required this.name, required this.bytes, this.mediaType});

  final String name;
  final Uint8List bytes;
  final String? mediaType;
}

const _epubMimetype = 'application/epub+zip';

const _containerXml = '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">\n'
    '  <rootfiles>\n'
    '    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>\n'
    '  </rootfiles>\n'
    '</container>\n';
