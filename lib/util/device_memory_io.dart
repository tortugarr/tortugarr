import 'dart:io';

/// /proc/meminfo on Android and Linux, null elsewhere.
String? readMeminfo() {
  if (!Platform.isAndroid && !Platform.isLinux) return null;
  try {
    return File('/proc/meminfo').readAsStringSync();
  } catch (_) {
    return null;
  }
}
