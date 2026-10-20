import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/models/aggregated_item.dart';
import '../../../data/services/download/bazarr_client.dart';
import '../../../data/services/subtitle_backend.dart';
import '../../../data/services/tortugarr/download_features.dart';
import '../../../data/services/tortugarr/plugin_subtitle_service.dart';
import '../focus/focusable_wrapper.dart';
import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// "Finn undertekster": shows which of Norwegian/English a movie or episode
/// has, lets Bazarr search right away, or lists every subtitle the providers
/// offer so the user can pick one.
Future<void> showFindSubtitlesDialog(BuildContext context, AggregatedItem item) {
  final title = item.type == 'Episode' && item.parentIndexNumber != null && item.indexNumber != null
      ? '${item.seriesName ?? item.name} · S${item.parentIndexNumber}E${item.indexNumber}'
      : item.name;
  return showStyledPlayerDialog<void>(
    context,
    title: appL10n().tgFindSubtitles,
    subtitle: title,
    maxWidth: 640,
    builder: (_) => _FindSubtitlesBody(item: item),
  );
}

String _languageName(String code) => switch (code) {
      'no' => appL10n().tgLangNorwegian,
      'en' => appL10n().tgLangEnglish,
      _ => code.toUpperCase(),
    };

class _FindSubtitlesBody extends StatefulWidget {
  final AggregatedItem item;
  const _FindSubtitlesBody({required this.item});

  @override
  State<_FindSubtitlesBody> createState() => _FindSubtitlesBodyState();
}

class _FindSubtitlesBodyState extends State<_FindSubtitlesBody> {
  final SubtitleBackend<Object> _service =
      DownloadFeatures.viaPlugin ? PluginSubtitleService() : BazarrSubtitleService();

  Object? _target;
  BazarrSubtitleState? _state;
  String? _error;
  String? _notice;
  bool _searching = false;

  // Manual mode: null = not opened, empty = nothing found.
  bool _manual = false;
  List<BazarrCandidate>? _candidates;
  String? _downloadingId;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final target = await _service.resolve(widget.item);
      if (target == null) {
        _fail(appL10n().tgSubsNotManaged);
        return;
      }
      final state = await _service.state(target);
      if (!mounted) return;
      setState(() {
        _target = target;
        _state = state;
      });
    } catch (e) {
      _fail(_friendly(e));
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _friendly(Object e) => e is BazarrException
      ? e.message
      : appL10n().tgBazarrUnreachable;

  Future<void> _searchNow() async {
    final target = _target;
    final before = _state;
    if (target == null || before == null) return;
    setState(() {
      _searching = true;
      _notice = null;
    });
    try {
      final after = await _service.searchMissing(target, before.missing);
      final found = before.missing.difference(after.missing);
      if (!mounted) return;
      setState(() {
        _state = after;
        _notice = found.isEmpty
            ? appL10n().tgSubsFoundNothing
            : appL10n().tgSubsFound(found
                .map(_languageName)
                .join(' ${appL10n().tgAnd} ')
                .toLowerCase());
      });
    } catch (e) {
      if (mounted) setState(() => _notice = _friendly(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openManual() async {
    final target = _target;
    if (target == null) return;
    setState(() {
      _manual = true;
      _candidates = null;
      _notice = null;
      _downloaded = false;
    });
    try {
      final list = await _service.candidates(target);
      if (mounted) setState(() => _candidates = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _candidates = const [];
          _notice = _friendly(e);
        });
      }
    }
  }

  Future<void> _download(BazarrCandidate candidate) async {
    final target = _target;
    if (target == null || _downloadingId != null) return;
    setState(() => _downloadingId = candidate.subtitleId);
    try {
      await _service.download(target, candidate);
      if (!mounted) return;
      setState(() {
        _downloaded = true;
        _notice = appL10n().tgSubsDownloaded;
      });
    } catch (e) {
      if (mounted) setState(() => _notice = _friendly(e));
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Colors.white12),
          ...(_manual ? _buildManual() : _buildOverview()),
        ],
      ),
    );
  }

  List<Widget> _buildOverview() {
    if (_error != null) {
      return [
        _message(_error!),
        const SizedBox(height: 20),
        SeerrDialogButton(
          label: appL10n().tgClose,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ];
    }
    final state = _state;
    if (state == null) {
      return [_spinner(appL10n().tgAskingBazarr)];
    }
    return [
      for (final (code, _) in bazarrWantedLanguages)
        _LanguageStatus(name: _languageName(code), has: state.have.contains(code)),
      if (_notice != null) ...[
        const SizedBox(height: 12),
        _message(_notice!),
      ],
      const SizedBox(height: 20),
      SeerrDialogButton(
        label: state.missing.isEmpty ? appL10n().tgHaveAll : appL10n().tgSearchAutoNow,
        primary: true,
        autofocus: true,
        busy: _searching,
        busyLabel: appL10n().tgSearchingUpToMinute,
        onPressed: _searching || state.missing.isEmpty ? null : _searchNow,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: SeerrDialogButton(
              label: appL10n().tgPickYourself,
              icon: Icons.list,
              onPressed: _searching ? null : _openManual,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SeerrDialogButton(
              label: appL10n().tgClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildManual() {
    final list = _candidates;
    return [
      if (list == null)
        _spinner(appL10n().tgAskingProviders)
      else if (list.isEmpty && _notice == null)
        _message(appL10n().tgNoProviderSubs)
      else
        for (var i = 0; i < list.length; i++)
          _CandidateRow(
            candidate: list[i],
            autofocus: i == 0,
            busy: _downloadingId == list[i].subtitleId,
            onSelect: _downloadingId != null || _downloaded
                ? null
                : () => _download(list[i]),
          ),
      if (_notice != null) ...[
        const SizedBox(height: 12),
        _message(_notice!, highlight: _downloaded),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: SeerrDialogButton(
              label: appL10n().tgBack,
              autofocus: list != null && (list.isEmpty || _downloaded),
              onPressed: _downloadingId != null
                  ? null
                  : () {
                      setState(() {
                        _manual = false;
                        _notice = null;
                        _state = null;
                      });
                      _load();
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SeerrDialogButton(
              label: appL10n().tgClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _spinner(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _message(String text, {bool highlight = false}) => Text(
        text,
        style: TextStyle(
          color: highlight ? Colors.greenAccent : Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      );
}

class _LanguageStatus extends StatelessWidget {
  final String name;
  final bool has;
  const _LanguageStatus({required this.name, required this.has});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            has ? Icons.check_circle : Icons.remove_circle_outline,
            size: 20,
            color: has ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 10),
          Text(
            has ? appL10n().tgLangHas(name) : appL10n().tgLangMissing(name),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final BazarrCandidate candidate;
  final bool autofocus;
  final bool busy;
  final VoidCallback? onSelect;

  const _CandidateRow({
    required this.candidate,
    required this.autofocus,
    required this.busy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FocusableWrapper(
        onSelect: onSelect,
        autofocus: autofocus,
        autoScroll: true,
        borderRadius: 10,
        disableScale: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: AppRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: AppRadius.circular(6),
                ),
                child: Text(
                  c.language.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.release.isEmpty ? appL10n().tgNoReleaseName : c.release,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.hearingImpaired == 'True'
                          ? appL10n().tgHearingImpaired(c.provider)
                          : c.provider,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${c.score} %',
                  style: TextStyle(
                    color: c.score >= 80 ? Colors.greenAccent : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
