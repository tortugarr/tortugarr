import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/log_service.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/artwork_timing.dart';
import '../../../util/focus/dpad_keys.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/settings/clean_settings_typography.dart';
import '../../widgets/settings/preference_tiles.dart';
import '../../../l10n/app_localizations.dart';
import 'package:moonfin/util/app_l10n.dart';
import '../../util/error_message.dart';
import 'settings_app_bar.dart';

class DiagnosticsSettingsScreen extends StatefulWidget {
  const DiagnosticsSettingsScreen({super.key});

  @override
  State<DiagnosticsSettingsScreen> createState() =>
      _DiagnosticsSettingsScreenState();
}

class _DiagnosticsSettingsScreenState extends State<DiagnosticsSettingsScreen> {
  LogService get _log => GetIt.instance<LogService>();

  bool _uploading = false;
  LogCategory? _filter;

  Future<void> _sendReport() async {
    setState(() => _uploading = true);
    ArtworkTimings.prepareReport();
    try {
      final fileName = await _log.uploadToServer();
      if (!mounted) return;
      _showSnack(
        fileName == null
            ? appL10n().tgDiagReportSent
            : appL10n().tgDiagReportSentFile(fileName),
      );
    } catch (e) {
      if (!mounted) return;
      final detail = describeError(e, AppLocalizations.of(context));
      _showSnack(appL10n().tgDiagSendFailed(detail));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _copyAll() async {
    ArtworkTimings.prepareReport();
    await Clipboard.setData(ClipboardData(text: _log.exportText()));
    _showSnack(appL10n().tgDiagLogsCopied);
  }

  Future<void> _copyEntry(LogEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.format()));
    _showSnack(appL10n().tgDiagEntryCopied);
  }

  void _clearLogs() {
    _log.clear();
    _showSnack(appL10n().tgDiagLogsCleared);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _supportsUpload => _log.canUploadToServer;

  Future<void> _pickFilter() async {
    final selected = await showFocusRestoringModalBottomSheet<_FilterChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<LogCategory?>(
          groupValue: _filter,
          onChanged: (value) => Navigator.pop(ctx, _FilterChoice(value)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<LogCategory?>(
                title: Text(appL10n().tgDiagAllCategories),
                value: null,
              ),
              for (final category in LogCategory.values)
                RadioListTile<LogCategory?>(
                  title: Text(_categoryLabel(category)),
                  value: category,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _filter = selected.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RequestInitialFocus(
      child: withCleanSettingsTypography(
        context,
        Scaffold(
          appBar: buildSettingsAppBar(
            context,
            Text(appL10n().tgDiagnosticsLogging),
          ),
          body: AnimatedBuilder(
            animation: _log,
            builder: (context, _) => _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final enabled = _log.isEnabled;
    final count = _log.entryCount;
    final hasEntries = count > 0;

    final entries = _log.entries
        .where((e) => _filter == null || e.category == _filter)
        .toList()
        .reversed
        .toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(title: appL10n().tgLogging),
              SwitchPreferenceTile(
                preference: UserPreferences.diagnosticLoggingEnabled,
                title: appL10n().tgDiagLoggingTitle,
                subtitle: appL10n().tgDiagLoggingSubtitle,
                icon: Icons.bug_report,
              ),
              SwitchPreferenceTile(
                preference: UserPreferences.crashReportsEnabled,
                title: appL10n().tgDiagCrashReports,
                subtitle: appL10n().tgDiagCrashReportsSubtitle,
                icon: Icons.report_outlined,
              ),
              _Section(
                title: enabled
                    ? appL10n().tgDiagReportsCount(count)
                    : appL10n().tgDiagReports,
              ),
              _ActionTile(
                icon: Icons.cloud_upload,
                title: appL10n().tgDiagSendReport,
                subtitle: _sendSubtitle(enabled),
                enabled:
                    enabled && hasEntries && _supportsUpload && !_uploading,
                trailing: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _sendReport,
              ),
              _ActionTile(
                icon: Icons.copy_all,
                title: appL10n().tgDiagCopyAll,
                subtitle: appL10n().tgDiagCopyAllSubtitle,
                enabled: hasEntries,
                onTap: _copyAll,
              ),
              _ActionTile(
                icon: Icons.delete_outline,
                title: appL10n().tgDiagClearLogs,
                subtitle: appL10n().tgDiagClearLogsSubtitle,
                enabled: hasEntries,
                destructive: true,
                onTap: _clearLogs,
              ),
              _Section(
                title: _filter == null
                    ? appL10n().tgDiagRecentLogs
                    : appL10n().tgDiagRecentLogsCount(entries.length, count),
              ),
              _ActionTile(
                icon: Icons.filter_list,
                title: appL10n().tgFilter,
                subtitle: _filter == null
                    ? appL10n().tgDiagAllCategories
                    : _categoryLabel(_filter!),
                enabled: enabled || hasEntries,
                trailing: const Icon(Icons.expand_more, size: 20),
                onTap: _pickFilter,
              ),
            ],
          ),
        ),
        if (entries.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(context, enabled))
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _LogTile(
                entry: entries[index],
                onTap: () => _copyEntry(entries[index]),
              ),
              childCount: entries.length,
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  String _sendSubtitle(bool enabled) {
    if (!enabled) return appL10n().tgDiagEnableFirst;
    if (!_supportsUpload) return _log.uploadUnavailableReason;
    if (_log.entryCount == 0) return appL10n().tgDiagNoEntriesYet;
    return appL10n().tgDiagUploadSubtitle;
  }

  Widget _buildEmptyState(BuildContext context, bool enabled) {
    final total = _log.entryCount;
    final filtered = _filter != null && total > 0;

    final IconData icon;
    final String message;
    if (filtered) {
      icon = Icons.filter_list_off;
      message = appL10n().tgDiagEmptyFiltered(_categoryLabel(_filter!), total);
    } else if (enabled) {
      icon = Icons.hourglass_empty;
      message = appL10n().tgDiagEmptyEnabled;
    } else {
      icon = Icons.toggle_off_outlined;
      message = appL10n().tgDiagEmptyOff;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: AppColorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryLabel(LogCategory category) => switch (category) {
    LogCategory.general => appL10n().general,
    LogCategory.media => appL10n().tgLogCatMedia,
    LogCategory.seerr => appL10n().tgLogCatSeerr,
    LogCategory.network => appL10n().network,
    LogCategory.auth => appL10n().authentication,
    LogCategory.playback => appL10n().playback,
    LogCategory.sync => appL10n().tgLogCatSync,
    LogCategory.artwork => appL10n().tgLogCatArtwork,
  };
}

class _FilterChoice {
  const _FilterChoice(this.value);
  final LogCategory? value;
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColorScheme.accent,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive
        ? AppColorScheme.statusRequested
        : AppColorScheme.accent;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (!event.logicalKey.isSelectKey) return KeyEventResult.ignored;
        if (event is KeyDownEvent && enabled) onTap();
        return KeyEventResult.handled;
      },
      child: TvFocusHighlight(
        builder: (context, focused) {
          final foreground = !enabled
              ? AppColorScheme.onSurface.withValues(alpha: 0.38)
              : focused
              ? AppColors.black.withValues(alpha: 0.87)
              : (destructive ? accent : AppColorScheme.onSurface);
          final iconColor = !enabled
              ? AppColorScheme.onSurface.withValues(alpha: 0.38)
              : focused
              ? AppColors.black.withValues(alpha: 0.7)
              : accent;

          return ListTile(
            enabled: enabled,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            leading: Icon(icon, color: iconColor),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: foreground.withValues(alpha: 0.7),
              ),
            ),
            trailing: trailing,
            onTap: enabled ? onTap : null,
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, required this.onTap});

  final LogEntry entry;
  final VoidCallback onTap;

  Color _levelColor() => switch (entry.level) {
    LogLevel.error => AppColorScheme.statusRequested,
    LogLevel.warning => AppColorScheme.statusPending,
    LogLevel.info => AppColorScheme.statusAvailable,
    LogLevel.debug => AppColorScheme.onSurface.withValues(alpha: 0.6),
  };

  @override
  Widget build(BuildContext context) {
    final time = entry.time;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    final levelColor = _levelColor();

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (!event.logicalKey.isSelectKey) return KeyEventResult.ignored;
        if (event is KeyDownEvent) onTap();
        return KeyEventResult.handled;
      },
      child: TvFocusHighlight(
        builder: (context, focused) {
          final textColor = focused
              ? AppColors.black.withValues(alpha: 0.87)
              : AppColorScheme.onSurface;
          return ListTile(
            dense: true,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            onTap: onTap,
            leading: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: levelColor,
                borderRadius: AppRadius.circular(2),
              ),
            ),
            title: Text(
              '$hh:$mm:$ss  ${entry.level.label}  ${entry.category.label}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: focused
                    ? AppColors.black.withValues(alpha: 0.7)
                    : levelColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
                if (entry.error != null)
                  Text(
                    entry.error!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: focused
                          ? AppColors.black.withValues(alpha: 0.7)
                          : AppColorScheme.statusRequested,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
