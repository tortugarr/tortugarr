import 'package:flutter/foundation.dart';

import 'device_memory_stub.dart' if (dart.library.io) 'device_memory_io.dart';

/// How much RAM the device has, so caches can be sized to it.
///
/// Budget Android TVs ship with about 2.5 GB that the GPU also draws from, and
/// their OEM memory guards kill whatever looks large. Sizing caches for a phone
/// or a desktop there gets the app (and the apps around it) killed.
class DeviceMemory {
  const DeviceMemory._();

  /// Devices with less total RAM than this keep caches small.
  static const int constrainedBelowKb = 3 * 1024 * 1024;

  static bool _read = false;
  static int? _totalKb;

  /// Total RAM in kB, or null where it can't be read (web, Apple platforms).
  static int? get totalKb {
    if (!_read) {
      _read = true;
      final meminfo = readMeminfo();
      _totalKb = meminfo == null ? null : parseMemTotalKb(meminfo);
    }
    return _totalKb;
  }

  static bool get isConstrained => isConstrainedTotal(totalKb);

  @visibleForTesting
  static bool isConstrainedTotal(int? totalKb) =>
      totalKb != null && totalKb < constrainedBelowKb;

  @visibleForTesting
  static int? parseMemTotalKb(String meminfo) {
    final match = RegExp(r'^MemTotal:\s+(\d+)\s*kB', multiLine: true)
        .firstMatch(meminfo);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @visibleForTesting
  static void debugSetTotalKb(int? totalKb) {
    _read = true;
    _totalKb = totalKb;
  }
}
