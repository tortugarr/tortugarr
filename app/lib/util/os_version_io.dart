import 'dart:io';

int osMajorVersion() {
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  if (match == null) return 0;
  return int.tryParse(match.group(0)!) ?? 0;
}
