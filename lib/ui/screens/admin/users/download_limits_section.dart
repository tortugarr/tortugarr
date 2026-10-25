import 'package:flutter/material.dart';

import '../../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/admin_form_styles.dart';

/// "Download limits" for a non-administrator (Tortugarr plugin, spec 3.16):
/// lets the user use Download Now within a size limit per movie and episode
/// and a count per week. Saved straight to the plugin with its own button,
/// apart from the Jellyfin policy.
class DownloadLimitsSection extends StatefulWidget {
  final String userId;
  final TortugarrPluginClient? client;

  const DownloadLimitsSection({super.key, required this.userId, this.client});

  @override
  State<DownloadLimitsSection> createState() => _DownloadLimitsSectionState();
}

class _DownloadLimitsSectionState extends State<DownloadLimitsSection> {
  late final TortugarrPluginClient _plugin = widget.client ?? TortugarrPluginClient();
  final _movieGb = TextEditingController();
  final _episodeMb = TextEditingController();
  final _moviesPerWeek = TextEditingController();
  final _episodesPerWeek = TextEditingController();
  TortugarrUserLimits? _limits;
  var _enabled = false;
  var _loading = true;
  var _saving = false;
  var _unavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _movieGb.dispose();
    _episodeMb.dispose();
    _moviesPerWeek.dispose();
    _episodesPerWeek.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _show(await _plugin.userLimits(widget.userId));
    } catch (e) {
      debugPrint('[DownloadLimits] could not load: $e');
      if (mounted) setState(() => _unavailable = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(TortugarrUserLimits l) {
    String n(int v) => v > 0 ? '$v' : '';
    final gb = l.maxMovieMb / 1024;
    setState(() {
      _limits = l;
      _enabled = l.enabled;
      _movieGb.text = l.maxMovieMb <= 0
          ? ''
          : (gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), ''));
      _episodeMb.text = n(l.maxEpisodeMb);
      _moviesPerWeek.text = n(l.moviesPerWeek);
      _episodesPerWeek.text = n(l.episodesPerWeek);
    });
  }

  Future<void> _save(AppLocalizations l10n) async {
    int whole(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    final gb = double.tryParse(_movieGb.text.trim().replaceAll(',', '.')) ?? 0;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final saved = await _plugin.setUserLimits(
        widget.userId,
        TortugarrUserLimits(
          enabled: _enabled,
          maxMovieMb: (gb * 1024).round(),
          maxEpisodeMb: whole(_episodeMb),
          moviesPerWeek: whole(_moviesPerWeek),
          episodesPerWeek: whole(_episodesPerWeek),
        ),
      );
      _show(saved);
      messenger?.showSnackBar(SnackBar(content: Text(l10n.tgLimitsSaved)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.adminFailed('$e'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c, {bool decimal = false}) => adminFieldRow(
        label: label,
        child: TextField(
          controller: c,
          enabled: _enabled,
          decoration: adminInputDecoration(),
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final limits = _limits;
    return adminSection(
      context,
      title: l10n.tgDownloadLimits,
      icon: Icons.download_for_offline_outlined,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_unavailable)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.tgLimitsUnavailable),
          )
        else ...[
          adminSwitchRow(
            title: l10n.tgDownloadLimitsEnable,
            subtitle: l10n.tgDownloadLimitsHelp,
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          _field(l10n.tgMaxMovieSizeGb, _movieGb, decimal: true),
          _field(l10n.tgMaxEpisodeSizeMb, _episodeMb),
          _field(l10n.tgMoviesPerWeek, _moviesPerWeek),
          _field(l10n.tgEpisodesPerWeek, _episodesPerWeek),
          if (limits != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l10n.tgLimitsUsedThisWeek(limits.moviesUsed, limits.episodesUsed)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: adminSaveButton(
              label: l10n.tgLimitsSave,
              saving: _saving,
              onPressed: () => _save(l10n),
            ),
          ),
        ],
      ],
    );
  }
}
