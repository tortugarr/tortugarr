import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/services/tortugarr/tortugarr_plugin_client.dart';

/// The Tortugarr plugin's settings as a screen made for the remote
/// (2026-11-08). The plugin's own web page could not be reached with the
/// D-pad inside the app. Each change is saved at once; keys are shown only as
/// set or not set.
class TortugarrServerSettingsScreen extends StatefulWidget {
  final TortugarrPluginClient? client;

  const TortugarrServerSettingsScreen({super.key, this.client});

  @override
  State<TortugarrServerSettingsScreen> createState() => _TortugarrServerSettingsScreenState();
}

enum _Kind { text, multiline, number, mb, gb, pattern, select }

class _Field {
  final String name;
  final String label;
  final String help;
  final _Kind kind;
  const _Field(this.name, this.label, [this.help = '', this.kind = _Kind.text]);
}

class _Service {
  final String id;
  final String name;
  final String url;
  final String key;
  final String? user;
  const _Service(this.id, this.name, this.url, this.key, [this.user]);
}

const _services = [
  _Service('sonarr', 'Sonarr', 'SonarrUrl', 'SonarrApiKey'),
  _Service('radarr', 'Radarr', 'RadarrUrl', 'RadarrApiKey'),
  _Service('prowlarr', 'Prowlarr', 'ProwlarrUrl', 'ProwlarrApiKey'),
  _Service('bazarr', 'Bazarr (subtitles)', 'BazarrUrl', 'BazarrApiKey'),
  _Service('seerr', 'Seerr', 'SeerrUrl', 'SeerrApiKey'),
];

const _downloads = [
  _Field('DownloadClientType', 'Download client', 'qBittorrent, Transmission, Deluge or none.', _Kind.select),
  _Field('DownloadClientUrl', 'Download client address'),
  _Field('DownloadClientUsername', 'Download client user name'),
  _Field('MovieCategory', 'Movie category', 'The download client category Radarr uses.'),
  _Field('TvCategory', 'Series category', 'The download client category Sonarr uses.'),
  _Field('DownloadRoots', 'Download folders', 'One per line: the folder as the client sees it | as Jellyfin sees it.', _Kind.multiline),
  _Field('MovieRoots', 'Movie folders', 'Radarr root folders for new movies, comma-separated. Empty = any.'),
  _Field('DocumentaryRoots', 'Documentary folders', 'Radarr root folders for documentaries, comma-separated.'),
  _Field('TvRoots', 'Series folders', 'Sonarr root folders for new series, comma-separated. Empty = any.'),
  _Field('SpaceBufferBytes', 'Free space to keep', 'Kept free on top of a download before the app offers to make room.', _Kind.gb),
  _Field('SearchTimeoutSeconds', 'Search time limit (seconds)', '', _Kind.number),
  _Field('TopLists', 'Top lists on Home', 'One per line: Title|mdblist-user/list.', _Kind.multiline),
];

const _adult = [
  _Field('AdultSavePath', 'Save path', 'Where adult downloads and the library live, as Jellyfin sees it.'),
  _Field('AdultDownloadPath', 'Save path for the download client', 'When the client sees the folder by another path. Empty = the save path.'),
  _Field('AdultFolders', 'More adult folders', 'One per line: as the client sees it | as Jellyfin sees it.', _Kind.multiline),
  _Field('AdultLibraryName', 'Library name'),
  _Field('AdultCategory', 'Download client category'),
  _Field('AdultCategories', 'Indexer categories', 'Newznab categories, comma-separated.'),
  _Field('AdultMinBytes', 'Smallest file', '', _Kind.mb),
  _Field('AdultUnsafeRegex', 'Unsafe names (pattern)', 'A release whose name matches is left out.', _Kind.pattern),
];

const _advanced = [
  _Field('MinMovieBytes', 'Smallest movie', '', _Kind.mb),
  _Field('MinEpisodeBytes', 'Smallest episode', '', _Kind.mb),
  _Field('MinSdMovieBytes', 'Smallest SD movie', '', _Kind.mb),
  _Field('MinSdEpisodeBytes', 'Smallest SD episode', '', _Kind.mb),
  _Field('MinVideoBytes', 'Smallest video file', 'A download without a file this big has no video.', _Kind.mb),
  _Field('EarlyReleaseDays', 'Early release days', 'A release this many days before the digital date is treated as fake.', _Kind.number),
  _Field('JunkRegex', 'Junk words (pattern)', 'CAM, telesync and the like.', _Kind.pattern),
  _Field('QualityRegex', 'Quality words (pattern)', 'A release must name a quality.', _Kind.pattern),
  _Field('HardRejectionRegex', 'Hard rejections (pattern)', 'Radarr/Sonarr reasons that leave a release out.', _Kind.pattern),
  _Field('BannedExtensions', 'Banned file types', 'Space-separated.'),
  _Field('VideoExtensions', 'Video file types', 'Space-separated.'),
];

const _clientTypes = ['qbittorrent', 'transmission', 'deluge', 'none'];

class _TortugarrServerSettingsScreenState extends State<TortugarrServerSettingsScreen> {
  late final TortugarrPluginClient _plugin = widget.client ?? TortugarrPluginClient();
  Map<String, dynamic>? _settings;
  String? _error;
  final Map<String, String> _tests = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final s = await _plugin.serverSettings();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save(Map<String, dynamic> change) async {
    try {
      final s = await _plugin.saveServerSettings(change);
      if (!mounted) return;
      setState(() => _settings = s);
      _snack('Saved');
    } catch (e) {
      _snack('Not saved: $e');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static String shown(_Field f, Object? v) {
    if (v == null || '$v'.isEmpty) return '-';
    final n = v is num ? v : num.tryParse('$v');
    return switch (f.kind) {
      _Kind.mb when n != null => '${(n / (1 << 20)).round()} MB',
      _Kind.gb when n != null => '${(n / (1 << 30)).toStringAsFixed(n % (1 << 30) == 0 ? 0 : 1)} GB',
      _Kind.multiline => '$v'.split('\n').where((l) => l.trim().isNotEmpty).join('  ·  '),
      _ => '$v',
    };
  }

  Future<void> _edit(_Field f) async {
    final s = _settings!;
    if (f.kind == _Kind.select) {
      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(f.label),
          children: [
            for (final (i, t) in _clientTypes.indexed)
              SimpleDialogOption(
                child: Focus(
                  autofocus: i == 0,
                  child: Text(t == s[f.name] ? '$t  ✓' : t),
                ),
                onPressed: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      );
      if (picked != null && picked != s[f.name]) await _save({f.name: picked});
      return;
    }
    final raw = s[f.name];
    final n = raw is num ? raw : num.tryParse('$raw');
    final initial = switch (f.kind) {
      _Kind.mb when n != null => '${(n / (1 << 20)).round()}',
      _Kind.gb when n != null => '${n / (1 << 30)}'.replaceAll(RegExp(r'\.0$'), ''),
      _ => raw == null ? '' : '$raw',
    };
    final text = await _ask(f.label, initial, help: f.help, multiline: f.kind == _Kind.multiline,
        numeric: f.kind == _Kind.number || f.kind == _Kind.mb || f.kind == _Kind.gb);
    if (text == null) return;
    final Object value = switch (f.kind) {
      _Kind.mb => ((double.tryParse(text.replaceAll(',', '.')) ?? 0) * (1 << 20)).round(),
      _Kind.gb => ((double.tryParse(text.replaceAll(',', '.')) ?? 0) * (1 << 30)).round(),
      _Kind.number => int.tryParse(text.trim()) ?? 0,
      _ => text,
    };
    await _save({f.name: value});
  }

  Future<String?> _ask(String title, String initial,
      {String help = '', bool multiline = false, bool numeric = false, bool secret = false}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (help.isNotEmpty) ...[Text(help), const SizedBox(height: 12)],
              TextField(
                controller: c,
                autofocus: true,
                obscureText: secret,
                maxLines: multiline ? 5 : 1,
                keyboardType: numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : (multiline ? TextInputType.multiline : TextInputType.text),
                inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
                onSubmitted: multiline ? null : (v) => Navigator.of(ctx).pop(v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _test(_Service svc) async {
    final s = _settings!;
    setState(() => _tests[svc.id] = '…');
    try {
      final r = await _plugin.testConnection(
        service: svc.id,
        url: '${s[svc.url] ?? ''}',
        username: svc.user == null ? '' : '${s[svc.user!] ?? ''}',
      );
      if (mounted) setState(() => _tests[svc.id] = r.ok ? '✓ ${r.text}' : '✗ ${r.text}');
    } catch (e) {
      if (mounted) setState(() => _tests[svc.id] = '✗ $e');
    }
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w700)),
      );

  Widget _fieldTile(_Field f, {bool autofocus = false}) => ListTile(
        autofocus: autofocus,
        title: Text(f.label),
        subtitle: Text(shown(f, _settings![f.name]), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => unawaited(_edit(f)),
      );

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Tortugarr settings')),
      body: s == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _header('Connections'),
                for (final (i, svc) in _services.indexed) ...[
                  ListTile(
                    autofocus: i == 0,
                    title: Text(svc.name),
                    subtitle: Text('${s[svc.url] ?? '-'}${_tests[svc.id] == null ? '' : '   ${_tests[svc.id]}'}'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final url = await _ask('${svc.name} address', '${s[svc.url] ?? ''}');
                      if (url != null) await _save({svc.url: url});
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 40, right: 16),
                    title: Text('${svc.name} API key'),
                    subtitle: Text(s['${svc.key}Set'] == true ? 'Set (hidden)' : 'Not set'),
                    trailing: TextButton(onPressed: () => unawaited(_test(svc)), child: const Text('Test')),
                    onTap: () async {
                      final key = await _ask('${svc.name} API key', '', help: 'Empty keeps the saved key.', secret: true);
                      if (key != null && key.trim().isNotEmpty) await _save({svc.key: key});
                    },
                  ),
                ],
                ListTile(
                  title: const Text('Download client password'),
                  subtitle: Text(s['DownloadClientPasswordSet'] == true ? 'Set (hidden)' : 'Not set'),
                  trailing: TextButton(
                    onPressed: () => unawaited(_test(const _Service('qbittorrent', 'Download client', 'DownloadClientUrl', 'DownloadClientPassword', 'DownloadClientUsername'))),
                    child: Text(_tests['qbittorrent'] ?? 'Test'),
                  ),
                  onTap: () async {
                    final pw = await _ask('Download client password', '', help: 'Empty keeps the saved password.', secret: true);
                    if (pw != null && pw.trim().isNotEmpty) await _save({'DownloadClientPassword': pw});
                  },
                ),
                _header('Downloads'),
                for (final f in _downloads) _fieldTile(f),
                _header('Adult library'),
                SwitchListTile(
                  title: const Text('Adult library'),
                  subtitle: const Text('Search and download adult releases in the app (PIN in the app settings).'),
                  value: s['AdultEnabled'] == true,
                  onChanged: (v) => unawaited(_save({'AdultEnabled': v})),
                ),
                for (final f in _adult) _fieldTile(f),
                _header('Advanced'),
                for (final f in _advanced) _fieldTile(f),
              ],
            ),
    );
  }
}
