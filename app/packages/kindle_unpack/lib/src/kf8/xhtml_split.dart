import 'dart:typed_data';

import '../headers/header_exception.dart';
import 'skeleton_fragment.dart';

/// One reconstructed XHTML file from a KF8 book — output of
/// [XhtmlSplitter.split].
class XhtmlPart {
  const XhtmlPart({
    required this.fileNumber,
    required this.bytes,
  });

  /// 0-based skeleton index this part came from.
  final int fileNumber;

  /// Reconstructed XHTML body for this part.
  final Uint8List bytes;

  /// `partNNNN.xhtml`-style filename (KindleUnpack convention).
  String get filename =>
      'part${fileNumber.toString().padLeft(4, '0')}.xhtml';
}

/// Splices fragments into skeletons to reconstruct the individual XHTML
/// files that Kindlegen originally collapsed into the KF8 primary flow.
///
/// Direct port of `K8Processor.buildParts` from KindleUnpack's
/// `mobi_k8proc.py`. The shape is:
///
/// 1. For each skeleton, take the bytes the skeleton table points at.
/// 2. Walk that skeleton's fragments in order. Each fragment's content
///    sits in the primary flow immediately after the skeleton's bytes
///    (with subsequent fragments stacked after one another); its
///    `insertPosition` tells us where in the skeleton to splice it.
/// 3. The boundary heuristic from KindleUnpack handles malformed KF8
///    files where Kindlegen's splice point landed inside a tag — we
///    nudge the position to the nearest tag boundary.
class XhtmlSplitter {
  XhtmlSplitter._();

  static List<XhtmlPart> split({
    required Uint8List primaryFlow,
    required SkeletonTable skeletons,
    required FragmentTable fragments,
  }) {
    final parts = <XhtmlPart>[];
    var fragPtr = 0;
    for (final skel in skeletons.entries) {
      if (skel.end > primaryFlow.length) {
        throw HeaderException(
          'Skeleton ${skel.fileNumber} ends at ${skel.end}, past primary '
          'flow length ${primaryFlow.length}',
        );
      }
      // Mutable working buffer for this skeleton — we splice fragments
      // into it as we go.
      final working = List<int>.from(
        primaryFlow.sublist(skel.start, skel.end),
      );
      var basePtr = skel.end;

      for (var i = 0; i < skel.fragmentCount; i++) {
        if (fragPtr >= fragments.entries.length) {
          throw HeaderException(
            'Skeleton ${skel.fileNumber} expects fragment $i but the '
            'fragment table is exhausted',
          );
        }
        final frag = fragments.entries[fragPtr++];
        if (basePtr + frag.length > primaryFlow.length) {
          throw HeaderException(
            'Fragment $fragPtr extends to ${basePtr + frag.length}, past '
            'primary flow length ${primaryFlow.length}',
          );
        }
        final fragBytes = primaryFlow.sublist(basePtr, basePtr + frag.length);
        var insertAt = frag.insertPosition - skel.start;
        if (insertAt < 0 || insertAt > working.length) {
          throw HeaderException(
            'Fragment $fragPtr insert position $insertAt out of range '
            'for skeleton of length ${working.length}',
          );
        }
        insertAt = _adjustForPartialTag(working, insertAt);
        working.insertAll(insertAt, fragBytes);
        basePtr += frag.length;
      }

      parts.add(
        XhtmlPart(
          fileNumber: skel.fileNumber,
          bytes: Uint8List.fromList(working),
        ),
      );
    }
    return List.unmodifiable(parts);
  }

  /// If the splice point lands inside an unclosed `<...>` tag (because
  /// Kindlegen miscounted), back up to the previous `>` so the splice
  /// preserves tag structure. Mirrors the heuristic in KindleUnpack.
  static int _adjustForPartialTag(List<int> working, int insertAt) {
    final headLastClose = _lastIndexOf(working, 0x3E, insertAt); // '>'
    final headLastOpen = _lastIndexOf(working, 0x3C, insertAt); // '<'
    final tailFirstClose = _indexOf(working, 0x3E, insertAt);
    final tailFirstOpen = _indexOf(working, 0x3C, insertAt);

    final headPartial =
        headLastClose >= 0 && headLastOpen >= 0 && headLastClose < headLastOpen;
    final tailPartial = tailFirstClose >= 0 &&
        (tailFirstOpen < 0 || tailFirstClose < tailFirstOpen);

    if (!headPartial && !tailPartial) return insertAt;
    // Back up to just past the last '>' before insertAt; if there isn't
    // one, we leave insertAt where it was (best effort).
    return headLastClose >= 0 ? headLastClose + 1 : insertAt;
  }

  static int _lastIndexOf(List<int> bytes, int byte, int end) {
    for (var i = end - 1; i >= 0; i--) {
      if (bytes[i] == byte) return i;
    }
    return -1;
  }

  static int _indexOf(List<int> bytes, int byte, int start) {
    for (var i = start; i < bytes.length; i++) {
      if (bytes[i] == byte) return i;
    }
    return -1;
  }
}
