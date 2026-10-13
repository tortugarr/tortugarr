import 'package:get_it/get_it.dart';

import '../../models/aggregated_item.dart';
import '../log_service.dart';
import 'cast_target.dart';

/// Writes to the diagnostic log when it is up, since casting problems only
/// ever surface on someone else's device and the log is all a report carries.
void castDiag(
  String message, {
  LogLevel level = LogLevel.debug,
  Object? error,
}) {
  if (GetIt.instance.isRegistered<LogService>()) {
    GetIt.instance<LogService>().playback(
      '[Cast] $message',
      level: error != null ? LogLevel.warning : level,
      error: error,
    );
  }
}

abstract class CastProvider {
  Set<CastTargetKind> get supportedKinds;

  Future<List<CastTarget>> discoverTargets(AggregatedItem item);

  Future<void> playToTarget(
    CastTarget target, {
    required AggregatedItem item,
    List<AggregatedItem>? queueItems,
    int? startPositionTicks,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  });
}
