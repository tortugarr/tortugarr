import '../util/platform_detection.dart';

enum DolbyVisionRequiredProfile {
  profile5,
  profile7,
  profile8,
  profile7Or8,
  any,
}

class HdrStreamCapability {
  const HdrStreamCapability._();

  static bool isVideoStream(Map<String, dynamic> stream) {
    return (stream['Type']?.toString().toUpperCase() ?? '') == 'VIDEO';
  }

  static bool isDolbyVisionVideoStream(Map<String, dynamic> stream) {
    if (!isVideoStream(stream)) return false;

    final rangeType = _videoRangeTypeToken(stream);
    final codecDescriptor = _codecDescriptorToken(stream);

    return rangeType.contains('DOVI') ||
        rangeType.contains('DOLBYVISION') ||
        codecDescriptor.contains('DVHE') ||
        codecDescriptor.contains('DVH1') ||
        codecDescriptor.contains('DOVI');
  }

  static bool isHdr10PlusVideoStream(Map<String, dynamic> stream) {
    if (!isVideoStream(stream)) return false;

    final rangeType = _videoRangeTypeToken(stream);
    final codecDescriptor = _codecDescriptorToken(stream);

    return rangeType.contains('HDR10PLUS') ||
        codecDescriptor.contains('HDR10PLUS');
  }

  static DolbyVisionRequiredProfile? requiredDolbyVisionProfile(
    Map<String, dynamic> stream,
  ) {
    if (!isDolbyVisionVideoStream(stream)) {
      return null;
    }

    final rangeType = _videoRangeTypeToken(stream);
    final codecDescriptor = _codecDescriptorToken(stream);

    if (_containsAny(codecDescriptor, const ['DVHE05', 'DVH105', 'PROFILE5'])) {
      return DolbyVisionRequiredProfile.profile5;
    }
    if (_containsAny(codecDescriptor, const ['DVHE07', 'DVH107', 'PROFILE7'])) {
      return DolbyVisionRequiredProfile.profile7;
    }
    if (_containsAny(codecDescriptor, const ['DVHE08', 'DVH108', 'PROFILE8'])) {
      return DolbyVisionRequiredProfile.profile8;
    }

    if (rangeType.contains('WITHEL')) {
      return DolbyVisionRequiredProfile.profile7;
    }
    if (rangeType.contains('WITHHDR10PLUS') || rangeType.contains('WITHHDR10')) {
      return DolbyVisionRequiredProfile.profile7Or8;
    }
    if (rangeType == 'DOVI' || rangeType == 'DOLBYVISION') {
      return DolbyVisionRequiredProfile.profile5;
    }
    if (rangeType.contains('DOVI') &&
        !rangeType.contains('HDR10') &&
        !rangeType.contains('EL')) {
      return DolbyVisionRequiredProfile.profile5;
    }

    return DolbyVisionRequiredProfile.any;
  }

  static bool streamNeedsDolbyVisionProfileTranscode(
    Map<String, dynamic> stream, {
    bool allowDolbyVisionProfile7ElDirectPlay = false,
  }
  ) {
    final requiredProfile = requiredDolbyVisionProfile(stream);
    if (requiredProfile == null) {
      return false;
    }

    if (!PlatformDetection.supportsDolbyVision) {
      return false;
    }
    if (!PlatformDetection.hasDolbyVisionCodecCapabilities) {
      return false;
    }

    switch (requiredProfile) {
      case DolbyVisionRequiredProfile.profile5:
        return !PlatformDetection.supportsDoViProfile5;
      case DolbyVisionRequiredProfile.profile7:
        if (allowDolbyVisionProfile7ElDirectPlay) {
          return false;
        }
        return !PlatformDetection.supportsDoViProfile7;
      case DolbyVisionRequiredProfile.profile8:
        return !PlatformDetection.supportsDoViProfile8;
      case DolbyVisionRequiredProfile.profile7Or8:
        return !PlatformDetection.supportsDoViProfile7 &&
            !PlatformDetection.supportsDoViProfile8;
      case DolbyVisionRequiredProfile.any:
        return !PlatformDetection.supportsDoViProfile5 &&
            !PlatformDetection.supportsDoViProfile7 &&
            !PlatformDetection.supportsDoViProfile8;
    }
  }

  static String _videoRangeTypeToken(Map<String, dynamic> stream) {
    final value = stream['VideoRangeType']?.toString() ??
        stream['VideoRange']?.toString() ??
        '';
    return _normalizeToken(value);
  }

  static String _codecDescriptorToken(Map<String, dynamic> stream) {
    final values = <String>[
      stream['Codec']?.toString() ?? '',
      stream['CodecTag']?.toString() ?? '',
      stream['CodecTagString']?.toString() ?? '',
      stream['CodecId']?.toString() ?? '',
      stream['Profile']?.toString() ?? '',
    ];
    return _normalizeToken(values.join(' '));
  }

  static bool _containsAny(String value, List<String> candidates) {
    for (final candidate in candidates) {
      if (value.contains(candidate)) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeToken(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }
}
