import 'dart:convert';

import 'package:web/web.dart' as web;

import '../../util/server_url.dart';
import 'jellyfin_credentials_bridge_model.dart';

const _bootstrapStorageKey = 'moonfin_bootstrap_credentials';
const _maxBootstrapAgeMs = 6 * 60 * 60 * 1000;

Future<JellyfinBootstrapCredentials?> loadJellyfinBootstrapCredentials({
  String? preferredServerAddress,
}) async {
  try {
    final normalizedPreferred = normalizeServerBaseUrl(
      preferredServerAddress?.trim() ?? '',
    ).toLowerCase();

    final candidates = <JellyfinBootstrapCredentials>[];

    final bootstrapRaw =
        web.window.sessionStorage.getItem(_bootstrapStorageKey) ??
        web.window.localStorage.getItem(_bootstrapStorageKey);
    if (bootstrapRaw != null && bootstrapRaw.trim().isNotEmpty) {
      final decodedBootstrap = _decodeJson(bootstrapRaw);
      if (decodedBootstrap is Map<String, dynamic>) {
        if (_isFreshBootstrap(decodedBootstrap)) {
          candidates.addAll(_extractCandidates(decodedBootstrap));
        }
      }

      // Treat this as one-shot launch context so stale entries do not linger.
      web.window.sessionStorage.removeItem(_bootstrapStorageKey);
      web.window.localStorage.removeItem(_bootstrapStorageKey);
    }

    final legacyRawKeys = <String>{
      'jellyfin_credentials',
      'jellyfin-credentials',
      'jellyfin_credentials_v2',
      'jellyfin_credentials_v3',
      'emby_credentials',
    };
    final storages = <web.Storage>[
      web.window.localStorage,
      web.window.sessionStorage,
    ];

    for (final storage in storages) {
      for (final key in legacyRawKeys) {
        final raw = storage.getItem(key);
        if (raw == null || raw.trim().isEmpty) {
          continue;
        }
        final decoded = _decodeJson(raw);
        if (decoded == null) {
          continue;
        }
        candidates.addAll(_extractCandidates(decoded));
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    JellyfinBootstrapCredentials? firstValid;
    final seen = <String>{};

    for (final candidate in candidates) {
      final dedupeKey =
          '${candidate.serverAddress.toLowerCase()}|${candidate.userId.toLowerCase()}|${candidate.accessToken}';
      if (!seen.add(dedupeKey)) {
        continue;
      }

      firstValid ??= candidate;
      if (normalizedPreferred.isNotEmpty &&
          candidate.serverAddress.toLowerCase() == normalizedPreferred) {
        return candidate;
      }
    }

    return firstValid;
  } catch (_) {
    return null;
  }
}

Object? _decodeJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

bool _isFreshBootstrap(Map<String, dynamic> map) {
  final timestamp = _readInt(map, const ['timestamp', 'Timestamp']);
  if (timestamp == null || timestamp <= 0) {
    return true;
  }

  final age = DateTime.now().millisecondsSinceEpoch - timestamp;
  return age >= 0 && age <= _maxBootstrapAgeMs;
}

List<JellyfinBootstrapCredentials> _extractCandidates(Object decoded) {
  final candidates = <JellyfinBootstrapCredentials>[];

  if (decoded is List) {
    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }
      final map = _normalizeMap(entry);
      final direct = _candidateFromMap(map);
      if (direct != null) {
        candidates.add(direct);
      }
    }
    return candidates;
  }

  if (decoded is! Map) {
    return candidates;
  }

  final map = _normalizeMap(decoded);

  final direct = _candidateFromMap(map);
  if (direct != null) {
    candidates.add(direct);
  }

  for (final nestedKey in const ['credential', 'credentials', 'current']) {
    final nested = map[nestedKey];
    if (nested is! Map) {
      continue;
    }
    final nestedCandidate = _candidateFromMap(_normalizeMap(nested));
    if (nestedCandidate != null) {
      candidates.add(nestedCandidate);
    }
  }

  final servers =
      map['Servers'] ??
      map['servers'] ??
      map['ServerConnections'] ??
      map['serverConnections'];

  if (servers is List) {
    for (final entry in servers) {
      if (entry is! Map) {
        continue;
      }
      final serverCandidate = _candidateFromMap(_normalizeMap(entry));
      if (serverCandidate != null) {
        candidates.add(serverCandidate);
      }
    }
  } else if (servers is Map) {
    for (final entry in servers.values) {
      if (entry is! Map) {
        continue;
      }
      final serverCandidate = _candidateFromMap(_normalizeMap(entry));
      if (serverCandidate != null) {
        candidates.add(serverCandidate);
      }
    }
  }

  return candidates;
}

Map<String, dynamic> _normalizeMap(Map source) {
  return source.map((key, value) => MapEntry(key.toString(), value));
}

JellyfinBootstrapCredentials? _candidateFromMap(Map<String, dynamic> map) {
  final serverAddress = normalizeServerBaseUrl(
    _readString(
      map,
      const [
        'serverAddress',
        'ServerAddress',
        'ManualAddress',
        'manualAddress',
        'Address',
        'address',
        'Url',
        'url',
        'BaseUrl',
        'baseUrl',
        'LocalAddress',
        'localAddress',
        'RemoteAddress',
        'remoteAddress',
      ],
    ),
  );
  final accessToken = _readString(
    map,
    const ['AccessToken', 'accessToken', 'Token', 'token'],
  );

  var userId = _readString(
    map,
    const ['UserId', 'userId', 'CurrentUserId', 'currentUserId'],
  );

  if (userId.isEmpty) {
    final nestedUser = map['User'] ?? map['user'];
    if (nestedUser is Map) {
      userId = _readString(
        _normalizeMap(nestedUser),
        const ['Id', 'id', 'UserId', 'userId'],
      );
    }
  }

  if (serverAddress.isEmpty || accessToken.isEmpty || userId.isEmpty) {
    return null;
  }

  return JellyfinBootstrapCredentials(
    serverAddress: serverAddress,
    accessToken: accessToken,
    userId: userId,
  );
}

String _readString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value == null) {
      continue;
    }

    final text = value.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

int? _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
  }

  return null;
}
