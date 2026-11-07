import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import '../../../widgets/download_now/free_space_dialog.dart' show formatBytes;
import 'admin_form_styles.dart';

/// Server health on the admin dashboard (2026-11-08): every service Tortugarr
/// talks to, how full each library disk is and what Radarr, Sonarr and
/// Prowlarr warn about, from the plugin's GET /Health. Broken things used to
/// be found only by chance.
class TortugarrHealthCard extends StatefulWidget {
  /// Injectable for tests; defaults to the plugin.
  final Future<TortugarrHealth> Function()? load;

  const TortugarrHealthCard({super.key, this.load});

  @override
  State<TortugarrHealthCard> createState() => _TortugarrHealthCardState();
}

class _TortugarrHealthCardState extends State<TortugarrHealthCard> {
  TortugarrHealth? _health;
  bool _failed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final h = await (widget.load ?? () => TortugarrPluginClient().health())();
      if (!mounted) return;
      setState(() {
        _health = h;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  static Color _color(String level) => switch (level) {
        'error' => const Color(0xFFE05260),
        'warning' => const Color(0xFFE0A030),
        'info' => const Color(0xFF5BA4E6),
        _ => const Color(0xFF4CAF7A),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final h = _health;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final children = <Widget>[];
    if (_loading && h == null) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ));
    } else if (_failed && h == null) {
      children.add(ListTile(title: Text(l10n.tgHealthUnavailable)));
    } else if (h != null) {
      final summary = switch (h.overall) {
        'error' => l10n.tgHealthError,
        'warning' => l10n.tgHealthWarning,
        _ => l10n.tgHealthOk,
      };
      children.add(ListTile(
        leading: Icon(
          h.overall == 'ok' ? Icons.check_circle : (h.overall == 'error' ? Icons.error : Icons.warning_amber_rounded),
          color: _color(h.overall),
        ),
        title: Text(summary, style: const TextStyle(fontWeight: FontWeight.w700)),
      ));
      if (h.services.isNotEmpty) {
        children.add(_label(context, l10n.tgHealthServices));
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in h.services)
                Tooltip(
                  message: s.ok ? s.version : (s.message ?? l10n.tgHealthDown),
                  child: Chip(
                    avatar: Icon(s.ok ? Icons.check : Icons.close, size: 16, color: _color(s.ok ? 'ok' : 'error')),
                    label: Text(s.ok
                        ? (s.version.isEmpty ? s.name : '${s.name} ${s.version}')
                        : '${s.name} · ${l10n.tgHealthDown}'),
                  ),
                ),
            ],
          ),
        ));
      }
      if (h.disks.isNotEmpty) {
        children.add(_label(context, l10n.tgHealthDisks));
        for (final d in h.disks) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(d.drive ?? l10n.tgHealthDisk, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d.libraries.join(', '), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      l10n.tgHealthFree(formatBytes(d.freeBytes), formatBytes(d.totalBytes)),
                      style: TextStyle(color: d.level == 'ok' ? null : _color(d.level), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: d.usedFraction,
                    minHeight: 6,
                    color: _color(d.level),
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ));
        }
      }
      if (h.warnings.isNotEmpty) {
        children.add(_label(context, l10n.tgHealthWarnings));
        for (final w in h.warnings) {
          children.add(ListTile(
            dense: true,
            leading: Icon(
              w.level == 'info' ? Icons.info_outline : Icons.warning_amber_rounded,
              color: _color(w.level),
              size: 20,
            ),
            title: Text(w.message),
            subtitle: Text(w.source, style: muted),
          ));
        }
      }
    }
    children.add(Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: TextButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.tgHealthRefresh),
        ),
      ),
    ));

    return adminSection(context, title: l10n.tgHealthTitle, icon: Icons.monitor_heart_outlined, children: children);
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w700),
        ),
      );
}
