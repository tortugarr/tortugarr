import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/game_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Lets a test decide where cache and support storage sit, which is the whole
/// difference between tvOS and everywhere else.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider({required this.cache, required this.support});

  final String cache;
  final String support;

  @override
  Future<String?> getApplicationCachePath() async => cache;

  @override
  Future<String?> getApplicationSupportPath() async => support;
}

void main() {
  late Directory cache;
  late Directory support;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('moonfin_game_cache');
    support = Directory.systemTemp.createTempSync('moonfin_game_support');
  });

  tearDown(() {
    for (final dir in [cache, support]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  File seedSave(Directory root) {
    final dir = Directory('${root.path}/games/saves')
      ..createSync(recursive: true);
    return File('${dir.path}/game.srm')..writeAsStringSync('progress');
  }

  test('moves a save off the cache when support storage differs', () async {
    PathProviderPlatform.instance = _FakePathProvider(
      cache: cache.path,
      support: support.path,
    );
    seedSave(cache);

    await GameStorage.migrateOffCache();

    expect(File('${support.path}/games/saves/game.srm').existsSync(), isTrue);
    expect(Directory('${cache.path}/games/saves').existsSync(), isFalse);
  });

  test('keeps the save when both roots are the same directory', () async {
    // tvOS refuses to create Application Support, so saves live in the cache
    // directory. Migrating would copy the files onto themselves and then
    // delete what it had just walked.
    PathProviderPlatform.instance = _FakePathProvider(
      cache: cache.path,
      support: cache.path,
    );
    final save = seedSave(cache);

    await GameStorage.migrateOffCache();

    expect(save.existsSync(), isTrue);
    expect(save.readAsStringSync(), 'progress');
  });
}
