import 'dart:convert';

import 'package:server_core/server_core.dart';

import 'settings_save_retry.dart';

/// The durable "this pad is Player 1" choice, keyed by the privacy-safe profile
/// id the native side reports for a physical controller.
///
/// Keyed by player number, not libretro port index (port N is player N + 1;
/// that conversion happens at the platform channel boundary, not here), so
/// the saved file reads the way the UI talks.
///
/// Identical USB controllers can report the same profile id (derived from
/// vendor, product and descriptor). Which physical twin becomes Player 1 is
/// then arbitrary, though the native registry keeps it stable per session.
class NativeControllerPlayerAssignments {
  const NativeControllerPlayerAssignments(this.profileIdByPlayer);

  static const empty = NativeControllerPlayerAssignments({});

  /// Player number (1..[maxPlayers]) to controller profile id.
  final Map<int, String> profileIdByPlayer;

  static const maxPlayers = 4;

  bool get isEmpty => profileIdByPlayer.isEmpty;

  int? playerFor(String profileId) {
    for (final entry in profileIdByPlayer.entries) {
      if (entry.value == profileId) return entry.key;
    }
    return null;
  }

  /// Assigns [profileId] to [player], or clears its assignment when [player] is
  /// null.
  ///
  /// Assigning to an occupied slot swaps the two devices rather than dropping
  /// the occupant: the displaced device takes the slot this one vacated, or
  /// becomes unassigned if this one held none.
  NativeControllerPlayerAssignments withPlayer(String profileId, int? player) {
    final previous = playerFor(profileId);
    final next = Map<int, String>.from(profileIdByPlayer);

    if (player == null) {
      if (previous != null) next.remove(previous);
      return NativeControllerPlayerAssignments(Map.unmodifiable(next));
    }
    if (player < 1 || player > maxPlayers) return this;

    final displaced = next[player];
    next[player] = profileId;
    if (previous != null && previous != player) next.remove(previous);
    if (displaced != null && displaced != profileId && previous != null) {
      next[previous] = displaced;
    }
    return NativeControllerPlayerAssignments(Map.unmodifiable(next));
  }

  factory NativeControllerPlayerAssignments.fromJson(String json) =>
      tryFromJson(json) ?? empty;

  /// Parses a complete assignment document, returning null when it cannot be
  /// trusted as a persisted assignment payload.
  static NativeControllerPlayerAssignments? tryFromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final players = decoded['players'];
      if (players is! Map) return null;
      final parsed = <int, String>{};
      for (final entry in players.entries) {
        final player = int.tryParse(entry.key.toString());
        final profileId = entry.value?.toString() ?? '';
        if (player == null || player < 1 || player > maxPlayers) continue;
        if (profileId.isEmpty) continue;
        parsed[player] = profileId;
      }
      return NativeControllerPlayerAssignments(Map.unmodifiable(parsed));
    } catch (_) {
      return null;
    }
  }

  String toJson() => jsonEncode({
    'players': {
      for (final entry in profileIdByPlayer.entries)
        entry.key.toString(): entry.value,
    },
  });
}

const _assignmentsSaveId = 'moonfin-native-controller-players';

/// The result of reading persisted player assignments.
///
/// An empty document is a known first-run state, while a failed read leaves
/// the stored assignments unknown. Callers that may later write must preserve
/// that distinction so a live, empty fallback cannot replace unseen pins.
class ControllerPlayerAssignmentsLoad {
  const ControllerPlayerAssignmentsLoad(
    this.assignments, {
    required this.reachable,
  });

  final NativeControllerPlayerAssignments assignments;

  /// False when the saved document could not be read or decoded.
  final bool reachable;
}

/// Loads persisted player assignments without blocking gameplay when the
/// server is unavailable. The native side can still use discovery order, but
/// callers that offer edits must not persist them when [reachable] is false.
Future<ControllerPlayerAssignmentsLoad> loadControllerPlayerAssignmentsChecked(
  GamesApi games,
) async {
  try {
    final blob = await games.getSave(_assignmentsSaveId, kind: 'settings');
    if (blob == null || blob.isEmpty) {
      return const ControllerPlayerAssignmentsLoad(
        NativeControllerPlayerAssignments.empty,
        reachable: true,
      );
    }
    final assignments = NativeControllerPlayerAssignments.tryFromJson(
      utf8.decode(blob),
    );
    if (assignments == null) {
      return const ControllerPlayerAssignmentsLoad(
        NativeControllerPlayerAssignments.empty,
        reachable: false,
      );
    }
    return ControllerPlayerAssignmentsLoad(assignments, reachable: true);
  } catch (_) {
    return const ControllerPlayerAssignmentsLoad(
      NativeControllerPlayerAssignments.empty,
      reachable: false,
    );
  }
}

/// Persists [assignments], retrying transient transport failures. Throws when
/// the write ultimately fails so the caller can report a lost pin.
Future<void> saveControllerPlayerAssignments(
  GamesApi games,
  NativeControllerPlayerAssignments assignments, {
  Future<void> Function(Duration)? retryDelay,
}) => retryOnTransientFailure(
  () => games.putSave(
    _assignmentsSaveId,
    utf8.encode(assignments.toJson()),
    kind: 'settings',
  ),
  delay: retryDelay,
);
