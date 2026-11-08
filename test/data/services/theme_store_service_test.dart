import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/storage_path_service.dart';
import 'package:moonfin/data/services/theme_store_service.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStoragePathService extends StoragePathService {
  final Directory dir;
  _FakeStoragePathService(this.dir);

  @override
  Future<Directory> getThemeCacheDir() async => dir;
}

ThemeSpec _spec(String id) => ThemeSpec.fromJson(
  ThemeRegistry.availableThemes.values.first.toJson()
    ..['id'] = id
    ..['displayName'] = id,
);

void main() {
  late Directory themeDir;
  late ThemeStoreService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    themeDir = Directory.systemTemp.createTempSync('theme_store_test');
    service = ThemeStoreService(_FakeStoragePathService(themeDir));
  });

  tearDown(() {
    for (final spec in ThemeRegistry.storeThemes) {
      ThemeRegistry.removeStoreTheme(spec.id);
    }
    themeDir.deleteSync(recursive: true);
  });

  test('a saved theme survives losing the theme folder', () async {
    await service.saveStoreTheme(_spec('store_a'));
    ThemeRegistry.removeStoreTheme('store_a');
    themeDir.deleteSync(recursive: true);
    themeDir.createSync();

    await service.loadAndRegister();

    expect(service.savedStoreThemeIds(), {'store_a'});
  });

  test('themes saved as files by older builds move into preferences', () async {
    final legacy = Directory('${themeDir.path}/_store')..createSync();
    File(
      '${legacy.path}/store_b.json',
    ).writeAsStringSync(jsonEncode(_spec('store_b').toJson()));

    await service.loadAndRegister();

    expect(service.savedStoreThemeIds(), {'store_b'});
    expect(legacy.existsSync(), isFalse);

    ThemeRegistry.removeStoreTheme('store_b');
    await service.loadAndRegister();
    expect(service.savedStoreThemeIds(), {'store_b'});
  });

  test('a deleted theme stays deleted after a restart', () async {
    await service.saveStoreTheme(_spec('store_c'));
    await service.deleteStoreTheme('store_c');

    await service.loadAndRegister();

    expect(service.savedStoreThemeIds(), isEmpty);
  });
}
