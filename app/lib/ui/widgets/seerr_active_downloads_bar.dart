import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;

import '../../data/services/seerr_active_downloads_service.dart';
import '../navigation/destinations.dart';
import '../navigation/home_refresh_bus.dart';

/// Global, persistent status bar that shows every Seerr download currently
/// in flight. Hidden when no downloads are active. Tapping the body jumps
/// to the Seerr requests page; the per-row X hides a single download and
/// the header X hides the whole bar until the next genuine change.
class SeerrActiveDownloadsBar extends StatelessWidget {
  const SeerrActiveDownloadsBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!GetIt.instance.isRegistered<SeerrActiveDownloadsService>()) {
      return const SizedBox.shrink();
    }
    final service = GetIt.instance<SeerrActiveDownloadsService>();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.hasActive) return const SizedBox.shrink();
        return _SeerrActiveDownloadsBarBody(
          service: service,
          downloads: service.downloads,
        );
      },
    );
  }
}

class _SeerrActiveDownloadsBarBody extends StatelessWidget {
  final SeerrActiveDownloadsService service;
  final List<SeerrActiveDownload> downloads;
  const _SeerrActiveDownloadsBarBody({
    required this.service,
    required this.downloads,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColorScheme.accent;
    final onAccent = AppColorScheme.onAccent;
    const maxVisible = 3;
    final shown = downloads.take(maxVisible).toList();
    final overflow = downloads.length - shown.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(Destinations.seerrRequests),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(
                color: onAccent.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: onAccent.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seerr · ${downloads.length} active',
                        style: TextStyle(
                          color: onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _DismissButton(
                      tooltip: 'Hide all',
                      onTap: service.dismissAll,
                    ),
                    _DismissButton(
                      tooltip: 'Refresh Jellyfin library',
                      icon: Icons.refresh,
                      onTap: _refreshLibrary,
                    ),
                  ],
                ),
                for (final d in shown)
                  _DownloadRow(
                    download: d,
                    onDismiss: () => service.dismiss(d.requestId),
                  ),
                if (overflow > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 22),
                    child: Text(
                      '+ $overflow more',
                      style: TextStyle(
                        color: onAccent.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final SeerrActiveDownload download;
  final VoidCallback onDismiss;
  const _DownloadRow({required this.download, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final onAccent = AppColorScheme.onAccent;
    final isTv = download.mediaType == 'tv';
    final fraction = download.fraction.clamp(0.0, 1.0);
    final label = download.isImporting
        ? 'Importing'
        : '${(fraction * 100).round()}%';
    final suffix = download.is4k ? ' · 4K' : '';
    final mediaTag = isTv ? 'Series' : 'Movie';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$mediaTag · ${download.title}$suffix',
                        style: TextStyle(
                          color: onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: onAccent.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: AppRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: download.isImporting ? null : fraction,
                    backgroundColor: onAccent.withValues(alpha: 0.22),
                    color: onAccent,
                    minHeight: 2,
                  ),
                ),
              ],
            ),
          ),
          _DismissButton(
            tooltip: 'Hide',
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  const _DismissButton({required this.tooltip, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final onAccent = AppColorScheme.onAccent;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon ?? Icons.close,
            size: 14,
            color: onAccent.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

Future<void> _refreshLibrary() async {
  try {
    if (GetIt.instance.isRegistered<MediaServerClient>()) {
      await GetIt.instance<MediaServerClient>().adminLibraryApi.refreshLibrary();
    }
  } catch (_) {
    // Jellyfin is best-effort here — the user can still get a UI refresh
    // from the home screen, which is the part they actually see.
  }
  homeRefreshBus.requestNowOrAfterNavigation();
}
