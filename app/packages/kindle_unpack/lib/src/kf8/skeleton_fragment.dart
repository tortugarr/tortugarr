import 'dart:convert';

import '../headers/header_exception.dart';
import '../headers/mobi_header.dart';
import '../pdb.dart';
import 'indx.dart';

/// One row of the skeleton table: a slice of the primary KF8 flow that
/// holds the HTML scaffolding for one output XHTML part. Fragments
/// belonging to the same skeleton are spliced into it at byte positions
/// the fragment table records.
class SkeletonEntry {
  const SkeletonEntry({
    required this.fileNumber,
    required this.name,
    required this.fragmentCount,
    required this.start,
    required this.length,
  });

  /// 0-based skeleton index. Maps directly to the eventual output file
  /// name (`part0000.xhtml`, `part0001.xhtml`, …).
  final int fileNumber;

  /// Symbolic name from the INDX entry (e.g. `SKEL0000000000`).
  /// Mostly diagnostic — Kindlegen always uses sequential names.
  final String name;

  /// Number of fragments to splice into this skeleton.
  final int fragmentCount;

  /// Byte offset of the skeleton bytes within the primary HTML flow.
  final int start;

  /// Length of the skeleton bytes.
  final int length;

  int get end => start + length;
}

/// Parsed skeleton table sourced from the KF8 skeleton INDX records.
class SkeletonTable {
  const SkeletonTable({required this.entries});

  final List<SkeletonEntry> entries;

  /// Read the table at [MobiHeader.skeletonIndex]. Throws
  /// [HeaderException] when the field is unset / out of range.
  static SkeletonTable parse(PdbFile pdb, MobiHeader mobi) {
    final idx = mobi.skeletonIndex;
    if (idx == null || idx == MobiHeader.unset || idx == 0) {
      throw HeaderException(
        'MOBI header has no skeletonIndex; not a KF8 file?',
      );
    }
    final indx = IndxData.read(pdb, idx);
    final entries = <SkeletonEntry>[];
    for (var i = 0; i < indx.entries.length; i++) {
      final e = indx.entries[i];
      final fragmentCount = e.tagMap[1]?.first;
      final positions = e.tagMap[6];
      if (fragmentCount == null || positions == null || positions.length < 2) {
        throw HeaderException(
          'Skeleton entry $i is missing tag 1 or tag 6 (got ${e.tagMap})',
        );
      }
      entries.add(
        SkeletonEntry(
          fileNumber: i,
          name: latin1.decode(e.name),
          fragmentCount: fragmentCount,
          start: positions[0],
          length: positions[1],
        ),
      );
    }
    return SkeletonTable(entries: List.unmodifiable(entries));
  }
}

/// One row of the fragment table: a chunk of the primary KF8 flow that
/// gets spliced into a skeleton at [insertPosition].
class FragmentEntry {
  const FragmentEntry({
    required this.insertPosition,
    required this.idText,
    required this.fileNumber,
    required this.sequenceNumber,
    required this.start,
    required this.length,
  });

  /// Byte offset within the primary flow where this fragment slots
  /// into its skeleton. Decoded from the entry name (which Kindlegen
  /// stores as a zero-padded decimal string).
  final int insertPosition;

  /// CTOC string referenced by tag 2 — looks like
  /// `P-//*[@aid='UGI0']`. Used to anchor cross-fragment hyperlinks
  /// when the splicer rewrites IDs.
  final String idText;

  /// Index of the skeleton this fragment belongs to (matches
  /// [SkeletonEntry.fileNumber]).
  final int fileNumber;

  /// Order within the skeleton's fragment group.
  final int sequenceNumber;

  /// Byte offset of the fragment's content within the primary flow,
  /// relative to the end of the skeleton it belongs to.
  final int start;

  final int length;
}

/// Parsed fragment table sourced from the KF8 fragment INDX records.
class FragmentTable {
  const FragmentTable({required this.entries});

  final List<FragmentEntry> entries;

  /// Read the table at [MobiHeader.fragmentIndex]. Throws
  /// [HeaderException] when the field is unset / out of range.
  static FragmentTable parse(PdbFile pdb, MobiHeader mobi) {
    final idx = mobi.fragmentIndex;
    if (idx == null || idx == MobiHeader.unset || idx == 0) {
      throw HeaderException(
        'MOBI header has no fragmentIndex; not a KF8 file?',
      );
    }
    final indx = IndxData.read(pdb, idx);
    final entries = <FragmentEntry>[];
    for (var i = 0; i < indx.entries.length; i++) {
      final e = indx.entries[i];
      final ctocOff = e.tagMap[2]?.first;
      final fileNumber = e.tagMap[3]?.first;
      final seqNumber = e.tagMap[4]?.first;
      final positions = e.tagMap[6];
      if (ctocOff == null ||
          fileNumber == null ||
          seqNumber == null ||
          positions == null ||
          positions.length < 2) {
        throw HeaderException(
          'Fragment entry $i is missing required tags (got ${e.tagMap})',
        );
      }
      final ctocBytes = indx.ctoc[ctocOff];
      if (ctocBytes == null) {
        throw HeaderException(
          'Fragment entry $i references CTOC offset $ctocOff which is absent',
        );
      }
      final insertPosition = int.parse(latin1.decode(e.name));
      entries.add(
        FragmentEntry(
          insertPosition: insertPosition,
          idText: latin1.decode(ctocBytes),
          fileNumber: fileNumber,
          sequenceNumber: seqNumber,
          start: positions[0],
          length: positions[1],
        ),
      );
    }
    return FragmentTable(entries: List.unmodifiable(entries));
  }
}
