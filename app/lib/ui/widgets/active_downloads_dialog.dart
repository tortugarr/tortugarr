import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;

import '../../auth/repositories/user_repository.dart';
import '../../data/services/seerr_active_downloads_service.dart';
import '../../data/services/tortugarr/download_features.dart';
import '../navigation/destinations.dart';
import '../navigation/home_refresh_bus.dart';
import 'download_now/free_space_dialog.dart';
import 'focus/focusable_wrapper.dart';
import 'seerr/seerr_tv_controls.dart';
import 'track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// The Seerr download bar as a d-pad friendly dialog. On TV the bar at the
/// bottom of the screen is out of reach of the focus system, so the toolbar
/// opens this instead. Same actions as the bar, plus freeing disk space.
Future<void> showActiveDownloadsDialog(BuildContext context) {
  return showStyledPlayerDialog<void>(
    context,
    title: appL10n().tgDownloads,
    maxWidth: 560,
    builder: (ctx) => const _ActiveDownloadsBody(),
  );
}

class _ActiveDownloadsBody extends StatelessWidget {
  const _ActiveDownloadsBody();

  @override
  Widget build(BuildContext context) {
    final service = GetIt.instance<SeerrActiveDownloadsService>();
    final isAdmin =
        GetIt.instance<UserRepository>().currentUser?.isAdministrator ?? false;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final downloads = service.downloads;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(color: Colors.white12),
              if (downloads.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    appL10n().tgNoActiveDownloads,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              for (var i = 0; i < downloads.length; i++)
                _DownloadRow(
                  download: downloads[i],
                  autofocus: i == 0,
                  onSelect: () {
                    Navigator.of(context).pop();
                    context.push(Destinations.seerrRequests);
                  },
                ),
              if (downloads.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    appL10n().tgPickDownloadToOpen,
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SeerrDialogButton(
                      label: appL10n().tgRefreshLibrary,
                      icon: Icons.refresh,
                      onPressed: () {
                        _refreshLibrary();
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text(appL10n().tgAskingJellyfinScan),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SeerrDialogButton(
                      label: appL10n().tgHideAll,
                      icon: Icons.visibility_off_outlined,
                      onPressed: downloads.isEmpty
                          ? null
                          : () {
                              service.dismissAll();
                              Navigator.of(context).pop();
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isAdmin && DownloadFeatures.freeSpace) ...[
                    Expanded(
                      child: SeerrDialogButton(
                        label: appL10n().tgFreeUpSpace,
                        icon: Icons.cleaning_services_outlined,
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final outer = navigator.context;
                          navigator.pop();
                          if (outer.mounted) {
                            await showManualFreeSpaceDialog(outer);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SeerrDialogButton(
                      label: appL10n().tgClose,
                      primary: true,
                      primaryColor: AppColorScheme.accent,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final SeerrActiveDownload download;
  final bool autofocus;
  final VoidCallback onSelect;

  const _DownloadRow({
    required this.download,
    required this.autofocus,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final d = download;
    final fraction = d.fraction.clamp(0.0, 1.0);
    final status = d.isImporting ? appL10n().tgImporting : '${(fraction * 100).round()} %';
    final tag = d.mediaType == 'tv' ? appL10n().tgSeriesTag : appL10n().tgMovieTag;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FocusableWrapper(
        onSelect: onSelect,
        autofocus: autofocus,
        autoScroll: true,
        borderRadius: 10,
        disableScale: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: AppRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$tag · ${d.title}${d.is4k ? ' · 4K' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: AppRadius.circular(3),
                child: LinearProgressIndicator(
                  value: d.isImporting ? null : fraction,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  color: AppColorScheme.accent,
                ),
              ),
            ],
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
    // Best effort, like the bar's own refresh button.
  }
  homeRefreshBus.requestNowOrAfterNavigation();
}
