import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk layout for native game playback.
///
/// ROMs can always be fetched from the server again, so they live in the cache
/// directory the OS is free to reclaim. Saves and BIOS files can't: a cache
/// clear would wipe someone's progress, so those live in support storage.
class GameStorage {
  const GameStorage._();

  /// Written next to a cached ROM so the storage screen can name the game
  /// without asking the server, which matters when the TV is offline.
  static const _metaFile = '.game';

  static Future<Directory> _dir(Directory parent, String name) async {
    final dir = Directory('${parent.path}/$name');
    await dir.create(recursive: true);
    return dir;
  }

  /// Holds one folder per cached game, keyed by library and game id.
  static Future<Directory> romsRoot() async =>
      _dir(await getApplicationCacheDirectory(), 'games/cache');

  static Future<Directory> romDir(String libraryId, String gameId) async =>
      _dir(await romsRoot(), '$libraryId/$gameId');

  static Future<Directory> systemDir() async =>
      _dir(await getApplicationSupportDirectory(), 'games/system');

  static Future<Directory> saveDir() async =>
      _dir(await getApplicationSupportDirectory(), 'games/saves');

  /// Moves saves and BIOS files off the cache directory, where earlier builds
  /// put them. Costs two directory checks once everything has moved.
  static Future<void> migrateOffCache() async {
    final cacheRoot = await getApplicationCacheDirectory();
    for (final name in ['saves', 'system']) {
      final legacy = Directory('${cacheRoot.path}/games/$name');
      if (!await legacy.exists()) continue;
      final target = name == 'saves' ? await saveDir() : await systemDir();
      try {
        await for (final entry in legacy.list()) {
          if (entry is! File) continue;
          final moved = File('${target.path}/${p.basename(entry.path)}');
          if (await moved.exists()) continue;
          await entry.copy(moved.path);
        }
        await legacy.delete(recursive: true);
      } on FileSystemException {
        // Leave the old copy alone so the next launch can try again.
      }
    }
  }

  static Future<void> writeMeta(
      Directory romDir, String title, String system) async {
    try {
      await File('${romDir.path}/$_metaFile')
          .writeAsString(jsonEncode({'title': title, 'system': system}));
    } on FileSystemException {
      // The name is only cosmetic, so a failure here is not worth surfacing.
    }
  }

  /// Every cached game, largest first.
  static Future<List<CachedGame>> list() async {
    final root = await romsRoot();
    final games = <CachedGame>[];
    await for (final library in root.list()) {
      if (library is! Directory) continue;
      await for (final game in library.list()) {
        if (game is! Directory) continue;
        final gameId = p.basename(game.path);
        final meta = await _readMeta(game);
        games.add(CachedGame(
          directory: game,
          bytes: await _sizeOf(game),
          title: meta?.title ?? gameId,
          system: meta?.system,
        ));
      }
    }
    games.sort((a, b) => b.bytes.compareTo(a.bytes));
    return games;
  }

  static Future<void> delete(CachedGame game) async {
    if (await game.directory.exists()) {
      await game.directory.delete(recursive: true);
    }
  }

  static Future<void> deleteAll() async {
    final root = await romsRoot();
    if (await root.exists()) await root.delete(recursive: true);
  }

  static Future<({String? title, String? system})?> _readMeta(
      Directory dir) async {
    final file = File('${dir.path}/$_metaFile');
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return (
        title: _nonEmpty(decoded['title']),
        system: _nonEmpty(decoded['system']),
      );
    } on Exception {
      return null;
    }
  }

  static String? _nonEmpty(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static Future<int> _sizeOf(Directory dir) async {
    var total = 0;
    try {
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File) total += await entry.length();
      }
    } on FileSystemException {
      // Report what was counted before the walk gave up.
    }
    return total;
  }
}

/// One game whose ROM is sitting on this device.
class CachedGame {
  const CachedGame({
    required this.directory,
    required this.bytes,
    required this.title,
    this.system,
  });

  final Directory directory;
  final int bytes;

  /// Falls back to the game id for anything cached before titles were kept.
  final String title;
  final String? system;

  String get sizeLabel => formatBytes(bytes);
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).round()} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}
