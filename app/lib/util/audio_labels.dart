String? audioLabelFromProfileCodec(String? profile, String? codec) {
  final normalizedProfile = profile?.trim().toLowerCase();
  if (normalizedProfile != null && normalizedProfile.contains('atmos')) {
    return 'Atmos';
  }

  final normalizedCodec = codec?.trim().toLowerCase();
  if (normalizedCodec == null || normalizedCodec.isEmpty) {
    return null;
  }

  final isDtsCodec =
      normalizedCodec == 'dts' ||
      normalizedCodec == 'dca' ||
      normalizedCodec.startsWith('dts') ||
      normalizedCodec.startsWith('dca');
  if (isDtsCodec) {
    if (normalizedProfile != null) {
      if (normalizedProfile.contains('dts:x') ||
          normalizedProfile.contains('dtsx')) {
        return 'DTS:X';
      }
      if (normalizedProfile.contains('hd ma') ||
          normalizedProfile.contains('hd-ma') ||
          normalizedProfile.contains('master audio')) {
        return 'DTS-HD MA';
      }
      if (normalizedProfile.contains('hd hra') ||
          normalizedProfile.contains('hd-hra') ||
          normalizedProfile.contains('high resolution')) {
        return 'DTS-HD HRA';
      }
      if (normalizedProfile.contains('hd')) {
        return 'DTS-HD';
      }
    }
    return 'DTS';
  }

  return normalizedCodec.toUpperCase();
}
