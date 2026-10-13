import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/game_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationCachePath() async => p.join(root.path, 'cache');
}

void main() {
  late Directory tempRoot;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('moonfin_game_storage');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempRoot);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await tempRoot.delete(recursive: true);
  });

  test('uses a fixed-length SHA-256 directory key for cached ROMs', () async {
    const libraryId = '69b89cb9129c660b351c17638c598c2d';
    const gameId =
        'L21lZGlhL1JldHJvR2FtZVJPTXMvTWFzdGVyIFN5c3RlbS9Xb3JsZCBDdXAgJzk0L1dvcmxkIEN1cCBVU0EgOTQgKEV1cm9wZSwgQnJhemlsKSAoRW4sRnIsRGUsRXMsSXQsTmwsUHQuU3YpLnNtcw==';

    final directory = await GameStorage.romDir(libraryId, gameId);

    expect(await directory.exists(), isTrue);
    expect(
      p.basename(directory.path),
      sha256.convert(gameId.codeUnits).toString(),
    );
    expect(p.basename(p.dirname(directory.path)), libraryId);
    expect(p.basename(directory.path), hasLength(64));
    expect(directory.path, isNot(contains(gameId)));
  });
}
