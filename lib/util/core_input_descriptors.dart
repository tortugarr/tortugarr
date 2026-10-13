/// Core-supplied, human-readable descriptions for RetroPad inputs, delivered
/// through RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS (see libretro_host.c's
/// `lh_input_descriptor` and LibretroBridge.kt's `NativeInputDescriptor`).
/// Turns the raw (port, device, index, id) -> label list into a lookup a
/// mapping UI can consult per button.
library;

import 'native_controller_mapping.dart' show retroDeviceJoypad;

/// One RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS entry.
class CoreInputDescriptor {
  const CoreInputDescriptor({
    required this.port,
    required this.device,
    required this.index,
    required this.id,
    required this.description,
  });

  final int port;
  final int device;
  final int index;
  final int id;
  final String description;

  factory CoreInputDescriptor.fromMap(Map<String, dynamic> map) {
    return CoreInputDescriptor(
      port: (map['port'] as num?)?.toInt() ?? -1,
      device: (map['device'] as num?)?.toInt() ?? -1,
      index: (map['index'] as num?)?.toInt() ?? -1,
      id: (map['id'] as num?)?.toInt() ?? -1,
      description: map['description']?.toString() ?? '',
    );
  }
}

/// Looks up a core's advertised label for a button by (port, id).
///
/// NAMING TRAP: libretro's RETRO_DEVICE_ID_JOYPAD_B is 0 and `_A` is 8 (SNES
/// positional naming), while this codebase's `RetroPadButton` calls index 0
/// 'A' and index 8 'B' (Android/Xbox naming). Both enumerations use the same
/// integers for the same physical buttons, so the raw-id lookup in [describe]
/// is correct as-is -- do not "fix" it by remapping the id.
class CoreInputDescriptors {
  const CoreInputDescriptors._(this._byPortDeviceAndId);

  /// port -> device (controller type) -> libretro id -> description.
  ///
  /// `device` is part of the key: FBNeo's Spy Hunter advertises both
  /// `port=0 device=1 id=0 'Missiles'` and `port=0 device=5 id=0 'Wheel'` for
  /// the same button under two controller types. Keying on (port, id) alone
  /// let the later entry silently overwrite the earlier one.
  final Map<int, Map<int, Map<int, String>>> _byPortDeviceAndId;

  static const empty = CoreInputDescriptors._({});

  /// Builds a lookup from the raw channel payload (a list of maps shaped like
  /// [CoreInputDescriptor.fromMap] expects). Entries with a negative
  /// port/device/id or an empty/whitespace-only description are dropped.
  factory CoreInputDescriptors.fromChannelPayload(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return empty;
    final byPortDeviceAndId = <int, Map<int, Map<int, String>>>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final descriptor = CoreInputDescriptor.fromMap(
        entry.cast<String, dynamic>(),
      );
      if (descriptor.port < 0 || descriptor.id < 0 || descriptor.device < 0) {
        continue;
      }
      final description = descriptor.description.trim();
      if (description.isEmpty) continue;
      final byDevice = byPortDeviceAndId.putIfAbsent(descriptor.port, () => {});
      final byId = byDevice.putIfAbsent(descriptor.device, () => {});
      byId[descriptor.id] = description;
    }
    if (byPortDeviceAndId.isEmpty) return empty;
    return CoreInputDescriptors._(byPortDeviceAndId);
  }

  /// The core's label for [id] on [port] under [device] (the controller type
  /// selected for that port, default [retroDeviceJoypad]), or null when the
  /// core described nothing for it. Never returns an empty string.
  ///
  /// Resolution order, most specific first: this port under [device], this
  /// port under the plain joypad, then the same two against port 0 -- many
  /// cores only describe port 0 and mean it for every port. No blind "any
  /// device" fallback, since a description for a layout the user isn't using
  /// is worse than none.
  String? describe(int port, int id, {int device = retroDeviceJoypad}) {
    for (final candidatePort in port == 0 ? const [0] : [port, 0]) {
      final byDevice = _byPortDeviceAndId[candidatePort];
      if (byDevice == null) continue;
      final exact = byDevice[device]?[id];
      if (exact != null) return exact;
      final generic = byDevice[retroDeviceJoypad]?[id];
      if (generic != null) return generic;
    }
    return null;
  }
}
