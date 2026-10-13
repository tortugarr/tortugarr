import 'package:flutter/material.dart';

import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../preference/user_preferences.dart';

import '../../data/services/adult_library_service.dart';
import '../../data/services/download/release_video_guard.dart';
import '../../data/services/download/xxx_download_service.dart';
import '../../data/services/tortugarr/download_features.dart';
import '../../data/services/tortugarr/tortugarr_plugin_client.dart';
import 'download_now/plugin_download_flow.dart' show asPickerRelease, explainPluginError, unavailableNote;
import 'download_now/plugin_search_progress.dart';
import 'download_now/release_picker_dialog.dart';
import '../navigation/home_refresh_bus.dart';
import 'pin_entry_dialog.dart';
import 'seerr/seerr_tv_controls.dart';
import 'track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// Settings > "Voksenfilmer (XXX)": show or hide the XXX library. Showing it
/// needs the library's own PIN (set the first time); hiding never does.
Future<void> showAdultLibraryDialog(BuildContext context) {
  return showStyledPlayerDialog<void>(
    context,
    title: appL10n().tgAdultTitle,
    subtitle: appL10n().tgAppliesAllDevices,
    builder: (_) => const _AdultLibraryBody(),
  );
}

class _AdultLibraryBody extends StatefulWidget {
  const _AdultLibraryBody();

  @override
  State<_AdultLibraryBody> createState() => _AdultLibraryBodyState();
}

class _AdultLibraryBodyState extends State<_AdultLibraryBody> {
  final _service = AdultLibraryService();
  bool _loading = true;
  bool _busy = false;
  bool? _visible;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final visible = await _service.isVisible();
      if (!mounted) return;
      setState(() {
        _visible = visible;
        _loading = false;
        _error = visible == null ? appL10n().tgNoXxxLibrary : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// First time: choose a PIN. Afterwards: enter it.
  Future<bool> _unlock() async {
    if (!_service.hasPin) {
      return PinEntryDialog.show(
        context,
        mode: PinEntryMode.set,
        onPinSet: _service.setPin,
      );
    }
    return PinEntryDialog.show(
      context,
      mode: PinEntryMode.verify,
      onVerify: _service.verifyPin,
    );
  }

  Future<void> _set(bool visible) async {
    if (_busy) return;
    if (visible && !await _unlock()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _service.setVisible(visible);
      homeRefreshBus.requestNowOrAfterNavigation();
      if (!mounted) return;
      setState(() {
        _visible = visible;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  /// Seerr cannot find adult titles (TMDB leaves them out), so search the
  /// indexers directly and download into the XXX folder.
  Future<void> _changePin() async {
    final ok = await PinEntryDialog.show(
      context,
      mode: PinEntryMode.verify,
      onVerify: _service.verifyPin,
    );
    if (!ok || !mounted) return;
    await PinEntryDialog.show(
      context,
      mode: PinEntryMode.set,
      onPinSet: _service.setPin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final status = _loading
        ? appL10n().tgChecking
        : _error ??
            (visible == true ? appL10n().tgXxxVisible : appL10n().tgXxxHidden);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Colors.white12),
          Text(
            status,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              if (visible != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SeerrDialogButton(
                    label: visible ? appL10n().tgHide : appL10n().tgShowWithPin,
                    icon: visible ? Icons.visibility_off : Icons.lock_open,
                    primary: true,
                    primaryColor: const Color(0xFFD32F2F),
                    busy: _busy,
                    onPressed: _busy ? null : () => _set(!visible),
                  ),
                ),
              ],
            ],
          ),
          if (visible != null && DownloadFeatures.adultDownloads) ...[
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: GetIt.instance<UserPreferences>(),
              builder: (_, __) {
                final prefs = GetIt.instance<UserPreferences>();
                return SeerrToggleRow(
                  title: appL10n().tgAdultSearchInMenu,
                  value: prefs.get(UserPreferences.adultSearchInMenu),
                  onChanged: (v) => unawaited(prefs.set(UserPreferences.adultSearchInMenu, v)),
                );
              },
            ),
          ],
          if (visible == true && DownloadFeatures.adultDownloads) ...[
            const SizedBox(height: 12),
            SeerrDialogButton(
              label: appL10n().tgSearchNewXxx,
              icon: Icons.search,
              onPressed: _busy ? null : () => unawaited(searchNewAdult(context)),
            ),
          ],
          if (visible != null && _service.hasPin) ...[
            const SizedBox(height: 12),
            SeerrDialogButton(
              label: appL10n().tgChangePin,
              onPressed: _busy ? null : _changePin,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Search for new XXX": asks for words, then searches the indexers and
/// downloads into the adult library. From the XXX settings and, when switched
/// on, from its own menu button.
Future<void> searchNewAdult(BuildContext context) async {
  final query = await _askAdultQuery(context);
  if (query == null || query.isEmpty || !context.mounted) return;
  if (DownloadFeatures.viaPlugin) return _searchNewAdultViaPlugin(context, query);
  final messenger = ScaffoldMessenger.maybeOf(context);
  // Every word is searched on its own across the indexers: ~30 s.
  messenger?.showSnackBar(SnackBar(
    content: Text(appL10n().tgSearchingEachWord),
    duration: const Duration(minutes: 2),
  ));
  final choice = await showReleasePickerDialog(
    context,
    title: 'XXX: $query',
    mediaType: 'xxx',
    query: query,
  );
  messenger?.hideCurrentSnackBar();
  if (choice == null) return;
  final release = choice.release;
  try {
    await XxxDownloadService().download(release);
    messenger?.showSnackBar(SnackBar(
      content: Text(appL10n().tgSentToQbit(release.title, release.sizeLabel)),
    ));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n().tgDownloadFailed('$e'))));
    return;
  }
  // Same check as Download Now: a torrent without a video file goes.
  unawaited(ReleaseVideoGuard()
      .watch(
    releaseTitle: release.title,
    guid: release.guid,
    magnetUrl: release.magnetUrl,
    isMovie: true,
    qbCategory: XxxDownloadService.category,
  )
      .then((result) {
    if (result.outcome == VideoCheckOutcome.removed ||
        result.outcome == VideoCheckOutcome.removeFailed) {
      messenger?.showSnackBar(SnackBar(
        content: Text(result.outcome == VideoCheckOutcome.removed
            ? appL10n().tgXxxNoVideoRemoved(release.title)
            : appL10n().tgXxxNoVideoNotRemoved(release.title)),
        duration: const Duration(seconds: 12),
      ));
    }
  }));
}

/// Public build: the server's Tortugarr plugin searches and downloads.
Future<void> _searchNewAdultViaPlugin(BuildContext context, String query) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final plugin = TortugarrPluginClient();
  try {
    final outcome = await showPluginSearchProgress<(String, List<TortugarrRelease>, List<String>)>(
      context,
      title: 'XXX: $query',
      start: (isCancelled) => plugin.adultSearch(query, isCancelled: isCancelled),
    );
    if (outcome.cancelled) return;
    if (outcome.error != null) throw outcome.error!;
    final (searchId, releases, unavailable) = outcome.value!;
    final note = unavailableNote(unavailable);
    if (releases.isEmpty) {
      messenger?.showSnackBar(SnackBar(
          content: Text(note == null ? 'No releases found' : 'No releases found. $note')));
      return;
    }
    if (!context.mounted) return;
    final byGuid = {for (final r in releases) r.guid: r};
    final choice = await showReleaseListDialog(
      context,
      title: 'XXX: $query',
      releases: [for (final r in releases) asPickerRelease(r)],
      browse: true,
      note: note,
    );
    final picked = choice == null ? null : byGuid[choice.release.guid];
    if (picked == null) return;
    final downloadId = await plugin.adultGrab(searchId, picked);
    messenger?.showSnackBar(SnackBar(
      content: Text(appL10n().tgSentToQbit(picked.title, asPickerRelease(picked).sizeLabel)),
    ));
    if (downloadId != null && DownloadFeatures.capabilities.value.videoCheck) {
      unawaited(plugin.watchVideo(downloadId).then((check) {
        if (check.action == TortugarrVideoAction.removed) {
          messenger?.showSnackBar(SnackBar(
            content: Text(appL10n().tgXxxNoVideoRemoved(picked.title)),
            duration: const Duration(seconds: 12),
          ));
        }
      }).catchError((Object _) {}));
    }
  } on TortugarrPluginException catch (e) {
    messenger?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(explainPluginError(e))));
  }
}

Future<String?> _askAdultQuery(BuildContext context) {
  final controller = TextEditingController();
  return showStyledPlayerDialog<String>(
    context,
    title: appL10n().tgSearchNewXxx,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: appL10n().tgXxxSearchHint),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgCancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgSearch,
                  primary: true,
                  primaryColor: const Color(0xFFD32F2F),
                  onPressed: () =>
                      Navigator.of(ctx).pop(controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
