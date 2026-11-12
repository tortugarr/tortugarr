import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../preference/user_preferences.dart';
import '../../models/aggregated_item.dart';
import '../../repositories/seerr_repository.dart';
import '../media_server_client_factory.dart';

/// What a title is: a blockbuster (BB), a mockbuster (MB), or neither.
enum TitleClass { blockbuster, mockbuster, plain }

/// A title's badge facts: its class (movies) and, for series, the network
/// that made it and that network's logo.
@immutable
class TitleBadgeInfo {
  const TitleBadgeInfo({this.kind = TitleClass.plain, this.network, this.networkLogo});

  final TitleClass kind;
  final String? network;
  final String? networkLogo;

  Map<String, dynamic> toJson() => {
        'k': kind.index,
        if (network != null) 'n': network,
        if (networkLogo != null) 'l': networkLogo,
      };

  static TitleBadgeInfo fromJson(Map<String, dynamic> j) => TitleBadgeInfo(
        kind: TitleClass.values[(j['k'] as int?)?.clamp(0, 2) ?? 2],
        network: j['n'] as String?,
        networkLogo: j['l'] as String?,
      );
}

/// Companies whose films are mockbusters (cheap same-name copies of big
/// releases). Matched on the production company name.
final _mockbusterStudios = RegExp(
  r'\b(the asylum|global asylum|mockbuster|brightlight pictures|cinedigm mockbuster)\b',
  caseSensitive: false,
);

/// The owner's rule (2026-11-12): MB = TMDB keyword "mockbuster" or a known
/// mockbuster studio; BB = budget >= $50M, revenue >= $100M or >= 5000 TMDB
/// votes; everything else plain.
@visibleForTesting
TitleClass classifyMovie(Map<String, dynamic> json) {
  final keywords = (json['keywords'] as List? ?? const [])
      .whereType<Map>()
      .map((k) => '${k['name']}'.toLowerCase());
  final companies = (json['productionCompanies'] as List? ?? const [])
      .whereType<Map>()
      .map((c) => '${c['name']}');
  if (keywords.contains('mockbuster') || companies.any(_mockbusterStudios.hasMatch)) {
    return TitleClass.mockbuster;
  }
  final budget = (json['budget'] as num?) ?? 0;
  final revenue = (json['revenue'] as num?) ?? 0;
  final votes = (json['voteCount'] as num?) ?? 0;
  if (budget >= 50000000 || revenue >= 100000000 || votes >= 5000) {
    return TitleClass.blockbuster;
  }
  return TitleClass.plain;
}

/// The network a series was made by (TMDB's first network) and its logo in
/// its own colours (shown on a light box).
@visibleForTesting
TitleBadgeInfo seriesInfo(Map<String, dynamic> json) {
  final nets = (json['networks'] as List? ?? const []).whereType<Map>().toList();
  if (nets.isEmpty) return const TitleBadgeInfo();
  final n = nets.first;
  final logo = n['logoPath'] as String?;
  return TitleBadgeInfo(
    network: n['name'] as String?,
    networkLogo: logo == null || logo.isEmpty
        ? null
        : 'https://image.tmdb.org/t/p/w185$logo',
  );
}

/// The studio a film is from: TMDB's first production company that has a
/// logo (TMDB lists the main one first: Warner Bros., Universal, Netflix,
/// Apple Original Films …), drawn white like the series networks.
/// The studios people know, in the order they win when a film lists several
/// (Oppenheimer: Universal, not Syncopy).
final _knownStudios = RegExp(
  r'^(warner bros|universal|paramount|walt disney|disney|pixar|marvel studios|lucasfilm|'
  r'20th century|twentieth century|columbia|sony pictures|tristar|lionsgate|lions gate|'
  r'metro-goldwyn-mayer|mgm|amazon|netflix|apple|a24|neon|legendary|dreamworks|'
  r'new line|focus features|searchlight|summit|blumhouse|illumination|hbo|max|'
  r'studiocanal|nordisk film|sf studios)',
  caseSensitive: false,
);

@visibleForTesting
TitleBadgeInfo movieInfo(Map<String, dynamic> json) {
  final kind = classifyMovie(json);
  final companies = (json['productionCompanies'] as List? ?? const []).whereType<Map>().toList();
  bool hasLogo(Map c) => (c['logoPath'] as String?)?.isNotEmpty == true;
  final known = companies.where((c) => hasLogo(c) && _knownStudios.hasMatch('${c['name']}'));
  final withLogo = companies.where(hasLogo);
  final pick = known.isNotEmpty
      ? known.first
      : (withLogo.isNotEmpty ? withLogo.first : (companies.isNotEmpty ? companies.first : null));
  final logo = pick?['logoPath'] as String?;
  return TitleBadgeInfo(
    kind: kind,
    network: pick?['name'] as String?,
    networkLogo: logo == null || logo.isEmpty
        ? null
        : 'https://image.tmdb.org/t/p/w185$logo',
  );
}

/// Looks up and remembers badge facts per TMDB id, through Seerr. Facts are
/// kept on the device (they barely change), so each title is asked once.
class TitleBadges extends ChangeNotifier {
  TitleBadges._();
  static final instance = TitleBadges._();

  final Map<String, TitleBadgeInfo> _known = {};
  final Set<String> _asking = {};
  bool _loaded = false;
  Timer? _saveTimer;

  static String? keyFor(AggregatedItem item) {
    // An episode or season carries its own ids, not the series': look the
    // series up on the server first (Stick, Widow's Bay in Continue
    // Watching).
    if (item.type == 'Episode' || item.type == 'Season') {
      final series = item.seriesId;
      if (series == null || series.isEmpty || item.serverId == 'seerr') {
        debugPrint('[TitleBadges] no series for ${item.type} ${item.name}: '
            '${item.rawData.keys.where((k) => '$k'.toLowerCase().contains('series')).toList()} server=${item.serverId}');
        return null;
      }
      return 'jfseries:${item.serverId}:$series';
    }
    final tmdb = item.tmdbId ?? (item.rawData['ProviderIds'] as Map?)?['Tmdb']?.toString();
    if (tmdb == null || tmdb.isEmpty || tmdb == '0') return null;
    final tv = item.type == 'Series';
    return '${tv ? 'tv' : 'movie'}:$tmdb';
  }

  /// The TMDB id of a series on a Jellyfin server, from its ProviderIds.
  Future<int?> _seriesTmdb(String serverId, String seriesId) async {
    final client = GetIt.instance<MediaServerClientFactory>().clientForServerOrActive(serverId);
    final res = await client.itemsApi.getItems(ids: [seriesId], fields: 'ProviderIds');
    final items = (res['Items'] as List? ?? const []).whereType<Map>();
    if (items.isEmpty) return null;
    final ids = items.first['ProviderIds'];
    final tmdb = ids is Map ? (ids['Tmdb'] ?? ids['tmdb'])?.toString() : null;
    return int.tryParse(tmdb ?? '');
  }

  UserPreferences? get _prefs =>
      GetIt.instance.isRegistered<UserPreferences>() ? GetIt.instance<UserPreferences>() : null;

  void _load() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = _prefs?.get(UserPreferences.tgBadgeCache) ?? '';
      if (raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((k, v) => _known[k] = TitleBadgeInfo.fromJson((v as Map).cast<String, dynamic>()));
    } catch (_) {}
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), () {
      // Keep the newest 3000.
      final entries = _known.entries.toList();
      final keep = entries.length > 3000 ? entries.sublist(entries.length - 3000) : entries;
      _prefs?.set(
        UserPreferences.tgBadgeCache,
        jsonEncode({for (final e in keep) e.key: e.value.toJson()}),
      );
    });
  }

  /// What is known now; asks Seerr in the background when not, and notifies
  /// listeners when the answer arrives.
  TitleBadgeInfo? infoFor(AggregatedItem item) {
    _load();
    final key = keyFor(item);
    if (key == null) return null;
    final known = _known[key];
    if (known != null) return known;
    if (_asking.add(key)) unawaited(_ask(key));
    return null;
  }

  Future<void> _ask(String key) async {
    try {
      final repo = await GetIt.instance.getAsync<SeerrRepository>();
      await repo.ensureInitialized();
      if (!repo.isAvailable) return;
      final TitleBadgeInfo info;
      if (key.startsWith('jfseries:')) {
        final parts = key.split(':');
        final tmdb = await _seriesTmdb(parts[1], parts.sublist(2).join(':'));
        debugPrint('[TitleBadges] $key -> series tmdb $tmdb');
        info = tmdb == null ? const TitleBadgeInfo() : seriesInfo(await repo.getTvDetailsRaw(tmdb));
      } else {
        final id = int.parse(key.split(':').last);
        info = key.startsWith('tv:')
            ? seriesInfo(await repo.getTvDetailsRaw(id))
            : movieInfo(await repo.getMovieDetailsRaw(id));
      }
      _known[key] = info;
      _scheduleSave();
      notifyListeners();
    } catch (e) {
      debugPrint('[TitleBadges] $key: $e');
    } finally {
      _asking.remove(key);
    }
  }
}
