import 'dart:io';

/// Reads the DWM-composition arrangement. See [hdr_composition.dart].
///
/// Unset - the normal case - selects technique 2, the validated default.
/// `MOONFIN_HDR_DWM=0` falls back to the overlay-capture arrangement, and
/// 1..4 picks a specific transparency technique.
int readDwmMode() {
  if (!Platform.isWindows) return 0;
  const fallback = 2;
  final raw = Platform.environment['MOONFIN_HDR_DWM']?.trim();
  if (raw == null || raw.isEmpty) return fallback;
  final mode = int.tryParse(raw);
  if (mode == null) return fallback;
  return mode >= 0 && mode <= 4 ? mode : fallback;
}
