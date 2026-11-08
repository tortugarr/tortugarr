import 'audio_capability_profile.dart';

/// Whether AetherEngine should bridge TrueHD and DTS to FLAC instead of EAC3.
///
/// The EAC3 encode stops at 5.1 and is lossy. FLAC keeps 7.1 lossless but
/// leaves as PCM, which a stereo-only route folds to two channels where EAC3
/// would still reach a soundbar as 5.1.
bool usesLosslessAudioBridge(
  AudioCapabilityProfile profile, {
  required int maxAudioChannels,
  required bool downmixToStereo,
}) {
  if (downmixToStereo || (maxAudioChannels > 0 && maxAudioChannels <= 2)) {
    return false;
  }
  return profile.isHdRoute && profile.maxPcmChannels > 2;
}
