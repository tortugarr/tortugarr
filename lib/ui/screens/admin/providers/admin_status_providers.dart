import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../admin_plugin_version_utils.dart';
import 'admin_user_providers.dart';
import '../../../../preference/user_preferences.dart';

class AdminNotificationSummary {
  final int pluginUpdateCount;
  final int restartPendingPluginCount;
  final List<String> restartPendingPlugins;
  final int failedTaskCount;

  const AdminNotificationSummary({
    this.pluginUpdateCount = 0,
    this.restartPendingPluginCount = 0,
    this.restartPendingPlugins = const [],
    this.failedTaskCount = 0,
  });

  bool get hasPluginUpdates => pluginUpdateCount > 0;

  bool get hasRestartPendingPlugins => restartPendingPluginCount > 0;

  bool get hasFailedTasks => failedTaskCount > 0;

  int get count =>
      (hasPluginUpdates ? 1 : 0) +
      (hasRestartPendingPlugins ? 1 : 0) +
      (hasFailedTasks ? 1 : 0);
}

/// The dashboard's Activity panel: user entries from the last 24 hours,
/// newest 7.
final adminDashboardActivityProvider =
    FutureProvider.autoDispose<ActivityLogResult>((ref) {
  return GetIt.instance<MediaServerClient>().adminSystemApi.getActivityLog(
    startIndex: 0,
    limit: 7,
    minDate: DateTime.now().subtract(const Duration(days: 1)),
    hasUserId: true,
  );
});

/// The dashboard's Alerts panel: system entries from the last 7 days,
/// newest 4.
final adminDashboardAlertsProvider =
    FutureProvider.autoDispose<ActivityLogResult>((ref) {
  return GetIt.instance<MediaServerClient>().adminSystemApi.getActivityLog(
    startIndex: 0,
    limit: 4,
    minDate: DateTime.now().subtract(const Duration(days: 7)),
    hasUserId: false,
  );
});

/// Alerts the administrator has not seen yet (user, 2026-11-08): warnings
/// count until the dashboard was looked at, so the tile turns orange for new
/// ones only; errors and critical alerts stay (red) until the alert list was
/// opened, so an important one can never be passed by unseen.
final adminUnseenAlertsProvider =
    FutureProvider.autoDispose<({int warnings, int errors})>((ref) async {
  final prefs = GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  DateTime since(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    return t.isAfter(weekAgo) ? t : weekAgo;
  }

  final warnSince = since(prefs?.get(UserPreferences.adminAlertsSeenAt) ?? 0);
  final errSince = since(prefs?.get(UserPreferences.adminErrorsSeenAt) ?? 0);
  final from = warnSince.isBefore(errSince) ? warnSince : errSince;
  final result = await GetIt.instance<MediaServerClient>().adminSystemApi.getActivityLog(
    startIndex: 0,
    limit: 200,
    minDate: from,
    hasUserId: false,
  );
  return countUnseenAlerts(result.items, warningsSince: warnSince, errorsSince: errSince);
});

/// Splits alerts into unseen warnings and unseen errors/critical ones.
@visibleForTesting
({int warnings, int errors}) countUnseenAlerts(
  Iterable<ActivityLogEntry> items, {
  required DateTime warningsSince,
  required DateTime errorsSince,
}) {
  var warnings = 0, errors = 0;
  for (final e in items) {
    final severity = e.severity.toLowerCase();
    if ((severity == 'error' || severity == 'critical') && e.date.isAfter(errorsSince)) {
      errors++;
    } else if (severity == 'warning' && e.date.isAfter(warningsSince)) {
      warnings++;
    }
  }
  return (warnings: warnings, errors: errors);
}

/// Warnings count as seen when the dashboard was looked at.
Future<void> markAdminAlertsSeen() async {
  if (!GetIt.instance.isRegistered<UserPreferences>()) return;
  await GetIt.instance<UserPreferences>()
      .set(UserPreferences.adminAlertsSeenAt, DateTime.now().millisecondsSinceEpoch);
}

/// Errors count as seen only when the alert list was opened.
Future<void> markAdminErrorsSeen() async {
  if (!GetIt.instance.isRegistered<UserPreferences>()) return;
  await GetIt.instance<UserPreferences>()
      .set(UserPreferences.adminErrorsSeenAt, DateTime.now().millisecondsSinceEpoch);
}

final adminNotificationSummaryProvider =
    FutureProvider.autoDispose<AdminNotificationSummary>((ref) async {
  try {
    final results = await Future.wait<dynamic>([
      ref.watch(adminInstalledPluginsProvider.future),
      ref.watch(adminAvailablePackagesProvider.future),
      // Only the failure count, so the live task feed's progress pushes don't
      // rebuild the summary every second.
      ref.watch(
        adminTasksProvider.selectAsync(
          (tasks) => tasks
              .where((task) => task.lastExecutionResult?.status == 'Failed')
              .length,
        ),
      ),
    ]);

    final installed = results[0] as List<PluginInfo>;
    final available = results[1] as List<PackageInfo>;
    final failedTaskCount = results[2] as int;

    final availableById = {
      for (final package in available)
        if (package.id.isNotEmpty) package.id: package,
    };

    final pluginUpdateCount = installed.where((plugin) {
      final package = availableById[plugin.id];
      if (package == null || plugin.version.isEmpty) {
        return false;
      }
      return package.versions.any((version) {
        if (version.version.isEmpty) {
          return false;
        }
        return compareVersionStrings(version.version, plugin.version) > 0;
      });
    }).length;

    final restartPendingPlugins = installed
        .where((plugin) =>
            plugin.status == PluginStatus.restart ||
            plugin.status == PluginStatus.deleted)
        .map((plugin) => plugin.name)
        .toList();

    return AdminNotificationSummary(
      pluginUpdateCount: pluginUpdateCount,
      restartPendingPluginCount: restartPendingPlugins.length,
      restartPendingPlugins: restartPendingPlugins,
      failedTaskCount: failedTaskCount,
    );
  } catch (_) {
    return const AdminNotificationSummary();
  }
});

/// Emby's Premiere license, null on Jellyfin.
final premiereStatusProvider = FutureProvider.autoDispose<PremiereStatus?>(
  (ref) =>
      GetIt.instance<MediaServerClient>().embyAdminApi?.getPremiereStatus() ??
      Future.value(),
);
