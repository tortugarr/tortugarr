import 'dart:convert';
import 'dart:typed_data';

import '../headers/header_exception.dart';
import 'fdst.dart';

/// Coarse classification of a flow's content. Determined by sniffing the
/// first non-whitespace bytes of the flow.
enum FlowKind {
  /// HTML / XHTML — primary book text.
  html,

  /// Cascading Style Sheet.
  css,

  /// Scalable Vector Graphics. Rare as a flow (more common as a separate
  /// image record), but KF8 occasionally inlines small SVGs here.
  svg,

  /// Anything we can't confidently classify — typically the small
  /// auxiliary flow that holds NCX / page-list / vendor metadata.
  other,
}

/// One flow inside a KF8 rawML stream. Built by [BookFlows.split].
class FlowSection {
  const FlowSection({
    required this.index,
    required this.kind,
    required this.bytes,
  });

  /// 0-based flow index, matching the FDST entry order.
  final int index;

  final FlowKind kind;

  /// Slice of rawML covering this flow. Zero-copy view of the input
  /// buffer.
  final Uint8List bytes;

  int get length => bytes.length;

  /// File-extension-style name suitable for EPUB packaging — `html` /
  /// `css` / `svg` / `dat` (the catch-all for unclassified flows).
  String get extension {
    switch (kind) {
      case FlowKind.html:
        return 'html';
      case FlowKind.css:
        return 'css';
      case FlowKind.svg:
        return 'svg';
      case FlowKind.other:
        return 'dat';
    }
  }
}

/// All the FDST-bounded flows of a KF8 book. The primary flow ([index]
/// 0) is the HTML body; subsequent flows are CSS, SVG, or auxiliary
/// data.
class BookFlows {
  const BookFlows({required this.flows});

  final List<FlowSection> flows;

  /// The HTML / XHTML flow. KF8 always places it at index 0; we still
  /// look it up by [FlowKind] so callers don't depend on that ordering.
  FlowSection? get primaryHtml {
    for (final f in flows) {
      if (f.kind == FlowKind.html) return f;
    }
    return null;
  }

  /// All flows of the given [kind], in declaration order.
  List<FlowSection> ofKind(FlowKind kind) =>
      flows.where((f) => f.kind == kind).toList(growable: false);

  /// Slice [rawML] into its flow-sections using the byte ranges from
  /// [fdst]. Each entry in [fdst] becomes one [FlowSection]. The flow
  /// kind is sniffed from the leading bytes of each slice.
  ///
  /// Throws [HeaderException] if any FDST entry is out-of-range against
  /// [rawML] — the caller's [FdstTable] should match the [rawML]
  /// produced by [decompressBookText] for the same book.
  static BookFlows split(Uint8List rawML, FdstTable fdst) {
    final out = <FlowSection>[];
    for (var i = 0; i < fdst.entries.length; i++) {
      final entry = fdst.entries[i];
      if (entry.start < 0 ||
          entry.end > rawML.length ||
          entry.start > entry.end) {
        throw HeaderException(
          'FDST entry $i [${entry.start}, ${entry.end}) is invalid for '
          'rawML length ${rawML.length}',
        );
      }
      final slice = Uint8List.sublistView(rawML, entry.start, entry.end);
      out.add(
        FlowSection(
          index: i,
          kind: _classify(slice),
          bytes: slice,
        ),
      );
    }
    return BookFlows(flows: List<FlowSection>.unmodifiable(out));
  }

  static FlowKind _classify(Uint8List bytes) {
    // Find first non-whitespace byte to anchor the sniff.
    var i = 0;
    while (i < bytes.length && _isWhitespace(bytes[i])) {
      i++;
    }
    if (i >= bytes.length) return FlowKind.other;
    final scanLen = (bytes.length - i).clamp(0, 256);
    final head = latin1.decode(
      Uint8List.sublistView(bytes, i, i + scanLen),
    );

    if (head.startsWith('<')) {
      // Likely an XML / HTML / SVG start.
      final lc = head.toLowerCase();
      if (lc.contains('<svg')) return FlowKind.svg;
      if (lc.contains('<html') ||
          lc.contains('<?xml') && lc.contains('<head')) {
        return FlowKind.html;
      }
      // KF8's primary flow doesn't always start with <html — older
      // ones lead with bare body fragments. Treat any '<' that isn't
      // SVG as HTML.
      return FlowKind.html;
    }

    if (head.startsWith('@') || head.startsWith('/*')) {
      // CSS — `@import`, `@charset`, comment, etc.
      return FlowKind.css;
    }
    // Heuristic: a flow that's mostly CSS-style selectors (contains '{'
    // and '}' near the start) is CSS. Otherwise other.
    if (head.contains('{') && head.contains('}')) {
      return FlowKind.css;
    }
    return FlowKind.other;
  }

  static bool _isWhitespace(int b) =>
      b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D;
}
