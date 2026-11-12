import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../preference/user_preferences.dart';
import '../../models/aggregated_item.dart';
import '../../repositories/seerr_repository.dart';

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

/// The network a series was made by (TMDB's first network) and its logo,
/// drawn white so it reads on a dark box.
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
        : 'https://image.tmdb.org/t/p/w154_filter(duotone,ffffff,bababa)$logo',
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
    final tmdb = item.tmdbId ?? (item.rawData['ProviderIds'] as Map?)?['Tmdb']?.toString();
    if (tmdb == null || tmdb.isEmpty || tmdb == '0') return null;
    final tv = item.type == 'Series' || item.type == 'Season' || item.type == 'Episode';
    if (item.type == 'Episode' || item.type == 'Season') return null; // their ids are the episode's
    return '${tv ? 'tv' : 'movie'}:$tmdb';
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
      final id = int.parse(key.split(':').last);
      final info = key.startsWith('tv:')
          ? seriesInfo(await repo.getTvDetailsRaw(id))
          : TitleBadgeInfo(kind: classifyMovie(await repo.getMovieDetailsRaw(id)));
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
