# kindle_unpack

A pure-Dart library for reading Amazon Kindle ebook files
(MOBI / AZW / AZW3 / KF8) and re-emitting them as EPUB 3.
Port of [KindleUnpack](https://github.com/kevinhendricks/KindleUnpack)
(Python).

## Why

The Dart / Flutter ecosystem has solid EPUB support (`epubx`) and PDF
support (`pdfx`, `pdfium` bindings), but nothing for Kindle's
MOBI-derived formats. Books bought from non-Kindle stores and saved as
`.azw3`, classic `.mobi` files from Project Gutenberg, and stripped-DRM
library archives all sit there unreadable by any Flutter app today.
The only way to view them on a Flutter device right now is to convert
them on a desktop with Calibre first.

This library plugs that hole: feed it bytes, get back HTML + metadata
+ images, or skip straight to a packaged EPUB.

## Install

```yaml
dependencies:
  kindle_unpack: ^0.1.0
```

## Usage

The one-shot path — bytes in, EPUB bytes out:

```dart
import 'dart:io';
import 'package:kindle_unpack/kindle_unpack.dart';

void main() {
  final bytes = File('book.azw3').readAsBytesSync();
  final book = KindleBook.fromBytes(bytes);
  File('book.epub').writeAsBytesSync(book.toEpub());
}
```

Or work with the parsed pieces directly:

```dart
final book = KindleBook.fromBytes(bytes);

book.title;                      // String — EXTH 503 / fullName
book.exth?.authors;              // List<String>?
book.exth?.asin;                 // String?
book.format;                     // KindleFormat.kf8Only / mobi7Only / combo

book.parts;                      // List<XhtmlPart> — reconstructed HTML
book.images.cover;               // ExtractedImage? — bytes + format
book.images.toMap();             // Map<String, Uint8List> — name → bytes
book.flows;                      // BookFlows? — KF8 only (HTML / CSS / …)
book.fonts;                      // List<FontResource> — already deobfuscated

book.rawML;                      // Uint8List — full decompressed text
```

Each layer is also exposed on its own — `PdbFile.parse`,
`PalmDocHeader.parse`, `MobiHeader.parse`, `ExthHeader.parse`,
`decompressBookText`, `BookFlows.split`, `XhtmlSplitter.split`, etc. See
the source under `lib/src/` for the typed parsers.

## What this supports

- **MOBI** (PalmDOC-compressed `.mobi`)
- **AZW** (Mobi-7 with the Amazon DRM section header zeroed out)
- **AZW3 / KF8** — standalone and dual MOBI/KF8 files
- **HUFF/CDIC** decompression (used in some MOBI files and KF8
  dictionaries)
- Cover and embedded image extraction (JPEG / PNG / GIF / BMP / SVG)
- Embedded font extraction with XOR-deobfuscation + zlib decompression
  (TTF / TTC / OTF)
- Metadata via EXTH headers (title, author, publisher, description,
  ASIN, ISBN, language, cover offset, KF8 boundary, …)
- KF8 flow splitting via the FDST table (HTML / CSS / SVG / auxiliary)
- KF8 XHTML reconstruction via the skeleton + fragment INDX records
- EPUB 3 packaging — `mimetype` first uncompressed, OPF manifest,
  NCX, all resources

## What this does NOT support

- **DRM removal.** Files encrypted with Amazon's PID/serial-key DRM
  stay encrypted. There are tools that remove Kindle DRM; this library
  is not one of them. Encrypted files raise an error.
- **Topaz / `.tpz` / `.azw1`.** Topaz is a separate, more obscure
  format. Out of scope.
- **Kindle Print Replica.** It's wrapped PDF — use a PDF library.
- **Flutter web.** The HUFF/CDIC decoder uses 64-bit shifts and the
  FONT decoder uses `dart:io`'s `ZLibCodec`; neither work in JS.
  Flutter native (mobile, desktop) and Dart VM are fully supported.

## Format primer

Kindle files are nested containers. From the outside in:

```
PDB (Palm Database)              ← the file itself; a record-based container
└── PalmDOC header               ← compression type, record count, text length
    └── MOBI header              ← Mobi version, encoding, EXTH offset, image
        │                         indices, etc.
        ├── EXTH header          ← key/value metadata records
        ├── Compressed text      ← HTML, in PalmDOC or HUFF/CDIC compression
        ├── Image records        ← raw JPEG/PNG/GIF
        ├── (KF8 only) FDST      ← record-section table for KF8 portion
        ├── (KF8 only) FONT      ← embedded fonts
        ├── (KF8 only) RESC      ← OPF/manifest description
        └── …
```

AZW3 / KF8 files are often "dual": they contain a legacy MOBI section
*and* a KF8 section in the same PDB, so old Kindles fall back gracefully.
`KindleFile.inspect` classifies the file and returns the appropriate
`KindleSection`(s).

## References

- **[KindleUnpack source][1]** — the reference implementation we
  ported. ~10k LoC of Python, GPL-3.
- **[MobileRead MOBI wiki][2]** — community reverse-engineering of the
  binary layout.
- **[Calibre's MOBI reader][3]** — independent C/Python implementation
  inside Calibre. Useful for cross-checking edge cases.
- **[Wikipedia: PalmDOC][4]** — for the PDB outer container.

[1]: https://github.com/kevinhendricks/KindleUnpack
[2]: https://wiki.mobileread.com/wiki/MOBI
[3]: https://github.com/kovidgoyal/calibre/tree/master/src/calibre/ebooks/mobi
[4]: https://en.wikipedia.org/wiki/PalmDOC

## License

**GPL-3.0** — KindleUnpack itself is GPL-3, and a port is a derivative
work, so this repo is required to be GPL-3. If you need a permissive
license you'd have to do a clean-room implementation from the format
specs (refs above) without consulting the KindleUnpack source. That's
genuinely a lot more work and is not what this project does.

## Contributing

If a phase looks fun and you want to take it on, open an issue first so
we don't duplicate. Real-world fixtures (especially HUFF/CDIC MOBI
dictionaries, books with embedded fonts, or unusual KF8 layouts) are
particularly welcome.
