import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/storage_path_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stands in for the Android side of path_provider, which is the only source
/// of the per-volume folders.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.volumes);

  final List<String>? volumes;

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => volumes;
}

void main() {
  late StoragePathService service;

  /// Both volumes are real directories so that dropping the built-in one is
  /// what keeps it out of the results, rather than it happening to be absent.
  late Directory builtIn;
  late Directory card;

  setUp(() {
    service = StoragePathService();
    builtIn = Directory.systemTemp.createTempSync('moonfin_builtin');
    card = Directory.systemTemp.createTempSync('moonfin_card');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    builtIn.deleteSync(recursive: true);
    card.deleteSync(recursive: true);
  });

  test('offers a folder on every volume past the built-in one', () async {
    PathProviderPlatform.instance = _FakePathProvider([
      builtIn.path,
      card.path,
    ]);

    final dirs = await service.getRemovableDownloadDirs();

    expect(dirs.map((d) => d.path), ['${card.path}/Moonfin']);
  });

  test('offers nothing on a device with only built-in storage', () async {
    PathProviderPlatform.instance = _FakePathProvider([builtIn.path]);

    expect(await service.getRemovableDownloadDirs(), isEmpty);
  });

  test('leaves the folder alone until something is downloaded', () async {
    PathProviderPlatform.instance = _FakePathProvider([
      builtIn.path,
      card.path,
    ]);

    await service.getRemovableDownloadDirs();

    expect(Directory('${card.path}/Moonfin').existsSync(), isFalse);
  });

  test('skips a volume that is no longer mounted', () async {
    PathProviderPlatform.instance = _FakePathProvider([
      builtIn.path,
      '${card.path}/ejected',
    ]);

    expect(await service.getRemovableDownloadDirs(), isEmpty);
  });

  test('offers nothing when path_provider gives nothing back', () async {
    PathProviderPlatform.instance = _FakePathProvider(null);

    expect(await service.getRemovableDownloadDirs(), isEmpty);
  });

  test('offers nothing off Android, which has no volumes to pick', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    PathProviderPlatform.instance = _FakePathProvider([
      builtIn.path,
      card.path,
    ]);

    expect(await service.getRemovableDownloadDirs(), isEmpty);
  });

  group('isOnRemovableStorage', () {
    test('a path under a volume past the built-in one is removable', () async {
      PathProviderPlatform.instance = _FakePathProvider([
        builtIn.path,
        card.path,
      ]);

      expect(
        await service.isOnRemovableStorage('${card.path}/Moonfin/TV/ep.mkv'),
        isTrue,
      );
    });

    test('the built-in volume is not removable', () async {
      PathProviderPlatform.instance = _FakePathProvider([
        builtIn.path,
        card.path,
      ]);

      expect(
        await service.isOnRemovableStorage('${builtIn.path}/Moonfin/ep.mkv'),
        isFalse,
      );
    });

    test('a sibling path sharing the volume prefix is not removable',
        () async {
      PathProviderPlatform.instance = _FakePathProvider([
        builtIn.path,
        card.path,
      ]);

      expect(
        await service.isOnRemovableStorage('${card.path}-2/Moonfin/ep.mkv'),
        isFalse,
      );
    });

    test('off Android nothing is removable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      PathProviderPlatform.instance = _FakePathProvider([
        builtIn.path,
        card.path,
      ]);

      expect(
        await service.isOnRemovableStorage('${card.path}/Moonfin/ep.mkv'),
        isFalse,
      );
    });
  });
}
