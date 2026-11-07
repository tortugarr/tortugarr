import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart';

import '../../../l10n/app_localizations.dart';
import '../../util/error_message.dart';
import '../../navigation/destinations.dart';
import 'admin_nav.dart';
import 'providers/admin_media_analytics_provider.dart';
import 'providers/admin_status_providers.dart';
import 'providers/admin_user_providers.dart';
import 'widgets/admin_form_styles.dart';
import 'widgets/admin_media_summary_section.dart';
import 'widgets/server_info_card.dart';
import 'widgets/server_paths_card.dart';
import 'widgets/active_sessions_card.dart';
import 'widgets/activity_log_card.dart';
import 'widgets/running_tasks_card.dart';
import 'widgets/server_actions_card.dart';
import '../../../data/services/tortugarr/download_features.dart';
import 'widgets/tortugarr_health_card.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late final MediaServerClient _client;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _systemInfo;
  StorageInfo? _storageInfo;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _client = GetIt.instance<MediaServerClient>();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final target = (position.pixels + event.scrollDelta.dy)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if (target != position.pixels) {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _client.systemApi.getSystemInfo(),
        _loadStorageInfo(),
      ]);
      if (!mounted) return;
      final systemInfo =
          Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
      final storageInfo = results[1] as StorageInfo?;

      final osDisplay =
          (systemInfo['OperatingSystemDisplayName'] ?? '').toString().trim();
      final osValue = (systemInfo['OperatingSystem'] ?? '').toString().trim();
      if (storageInfo != null && osDisplay.isEmpty && osValue.isEmpty) {
        final inferred = _inferOsFromStorage(storageInfo);
        if (inferred.isNotEmpty) {
          systemInfo['OperatingSystemDisplayName'] = inferred;
        }
      }

      setState(() {
        _systemInfo = systemInfo;
        _storageInfo = storageInfo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e, AppLocalizations.of(context));
        _loading = false;
      });
    }
  }

  Future<StorageInfo?> _loadStorageInfo() async {
    try {
      return await _client.adminSystemApi.getStorageInfo();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(adminDashboardActivityProvider)
      ..invalidate(adminDashboardAlertsProvider)
      ..invalidate(adminMediaSummaryProvider);
    await _loadData();
  }

  void _openActivity(bool userActivity) => context.push(
        '${Destinations.adminActivity}?useractivity=$userActivity',
      );

  String _inferOsFromStorage(StorageInfo storage) {
    final paths = [
      storage.programDataPath,
      storage.cachePath,
      storage.logPath,
      storage.internalMetadataPath,
      storage.transcodingTempPath,
    ].where((p) => p.trim().isNotEmpty).toList();

    if (paths.isEmpty) {
      return '';
    }

    final joined = paths.join(' | ');
    if (RegExp(r'^[A-Za-z]:\\').hasMatch(paths.first) || joined.contains('\\')) {
      return 'Windows';
    }
    if (joined.startsWith('/')) {
      if (joined.contains('/Users/')) {
        return 'macOS';
      }
      return 'Linux/Unix';
    }

    return '';
  }

  double? _worstStorageFill(StorageInfo? storage) {
    if (storage == null) return null;
    final fractions = [
      storage.programDataFolder?.usageFraction,
      storage.cacheFolder?.usageFraction,
      storage.transcodingTempFolder?.usageFraction,
      storage.logFolder?.usageFraction,
    ].whereType<double>().where((f) => f > 0).toList();
    if (fractions.isEmpty) return null;
    return fractions.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaSummary = ref.watch(adminMediaSummaryProvider);
    final notificationSummary = ref.watch(adminNotificationSummaryProvider);
    // One sessions list for the count and the card, kept live by its feed.
    final sessionCount = ref.watch(
      adminSessionsProvider.select((s) => s.valueOrNull?.length ?? 0),
    );
    final activity = ref.watch(adminDashboardActivityProvider).valueOrNull;
    final alerts = ref.watch(adminDashboardAlertsProvider).valueOrNull;
    final isEmby = AdminServerScope.isEmby(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminDashboardLoadFailed, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadData,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(context).padding.bottom + 40,
          ),
          children: [
            adminScreenHeader(
              context,
              title: l10n.adminDrawerDashboard,
              icon: Icons.dashboard,
            ),
            if (notificationSummary.valueOrNull case final summary?
                when summary.count > 0)
              _AdminAttentionCard(summary: summary),
            _DashboardKpiStrip(
              sessionCount: sessionCount,
              alertCount: alerts?.totalRecordCount ?? 0,
              worstStorageFill: _worstStorageFill(_storageInfo),
              // Emby reports its folders without their sizes.
              showDisk: !isEmby,
            ),
            // Radarr, Sonarr, qBittorrent & co. and the library disks (plugin).
            if (DownloadFeatures.viaPlugin && DownloadFeatures.capabilities.value.health)
              const TortugarrHealthCard(),
            ServerInfoCard(systemInfo: _systemInfo!),
            ServerActionsCard(
              client: _client,
              // Jellyfin's flag is obsolete, so only Emby's counts.
              canRestart: !isEmby || _systemInfo!['CanSelfRestart'] != false,
            ),
            mediaSummary.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => adminSection(
                context,
                title: l10n.adminMediaOverview,
                icon: Icons.perm_media_outlined,
                children: [
                  ListTile(
                    title: Text(l10n.adminMediaTotalsError),
                    trailing: FilledButton.tonal(
                      onPressed: () => ref.invalidate(adminMediaSummaryProvider),
                      child: Text(l10n.retry),
                    ),
                  ),
                ],
              ),
              data: (summary) => AdminMediaSummarySection(
                summary: summary,
                subtitle: l10n.adminMediaOverviewSubtitle,
                onOpenAnalytics: () => context.push(Destinations.adminAnalytics),
              ),
            ),
            const RunningTasksCard(),
            const ActiveSessionsCard(),
            ActivityLogCard(
              title: l10n.adminRecentActivity,
              icon: Icons.history,
              entries: activity?.items ?? const [],
              onOpen: () => _openActivity(true),
            ),
            if (alerts != null && alerts.items.isNotEmpty)
              ActivityLogCard(
                title: l10n.adminDashboardAlerts,
                icon: Icons.notification_important_outlined,
                entries: alerts.items,
                showOverview: false,
                onOpen: () => _openActivity(false),
              ),
            if (_storageInfo != null) ServerPathsCard(storageInfo: _storageInfo!),
          ],
        ),
      ),
    );
  }
}

class _AdminAttentionCard extends StatelessWidget {
  final AdminNotificationSummary summary;

  const _AdminAttentionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return adminSection(
      context,
      title: l10n.needsAttention,
      icon: Icons.notification_important,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceLg,
            vertical: AppSpacing.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.hasPluginUpdates)
                Text(l10n.adminPluginUpdatesAvailable(summary.pluginUpdateCount)),
              if (summary.hasRestartPendingPlugins)
                Text(l10n.adminPluginsRequiringRestart(
                    summary.restartPendingPluginCount)),
              if (summary.restartPendingPlugins.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary.restartPendingPlugins.take(3).join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (summary.hasFailedTasks)
                Text(
                  l10n.adminFailedScheduledTasks(summary.failedTaskCount),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardKpiStrip extends StatelessWidget {
  final int sessionCount;
  final int alertCount;
  final double? worstStorageFill;
  final bool showDisk;

  const _DashboardKpiStrip({
    required this.sessionCount,
    required this.alertCount,
    this.worstStorageFill,
    required this.showDisk,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fill = worstStorageFill;
    final Color storageColor = fill == null
        ? theme.colorScheme.primary
        : fill >= 0.90
            ? theme.colorScheme.error
            : fill >= 0.75
                ? AppColorScheme.recordingScheduled
                : AppColorScheme.statusAvailable;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.spaceLg),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.people_alt_outlined,
              label: l10n.sessions,
              value: '$sessionCount',
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.notification_important_outlined,
              label: l10n.adminDashboardAlerts,
              value: '$alertCount',
              color: alertCount > 0
                  ? AppColorScheme.recordingScheduled
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (showDisk) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.storage_outlined,
                label: l10n.disk,
                value: fill != null ? '${(fill * 100).round()}%' : '-',
                color: storageColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return adminListCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
