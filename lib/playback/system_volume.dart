import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:volume_controller/volume_controller.dart';

import '../util/platform_detection.dart';
import 'aether_backend.dart';

/// Follows the device volume for the player's volume controls. On iOS the
/// player reports it natively, because volume_controller's listener switches
/// the audio session to mix with others, which hands Now Playing and the
/// headphone and Control Center controls to another app.
StreamSubscription<double> listenToSystemVolume(
  void Function(double volume) onChanged,
) {
  if (PlatformDetection.isIOS && GetIt.instance.isRegistered<AetherBackend>()) {
    unawaited(VolumeController.instance.getVolume().then(onChanged));
    return GetIt.instance<AetherBackend>().systemVolumeStream.listen(onChanged);
  }
  return VolumeController.instance.addListener(onChanged);
}
