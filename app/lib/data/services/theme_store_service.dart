import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moonfin_design/moonfin_design.dart';

import 'storage_path_service.dart';

class ThemeStoreCatalogEntry {
  final String id;
  final String displayName;
  final String? description;
  final String file;

  const ThemeStoreCatalogEntry({
    required this.id,
    required this.displayName,
    this.description,
    required this.file,
  });
}

/// Fetches the community theme catalog from the Moonfin Themes repo and
/// persists store-saved themes in a dedicated directory, isolated from the
/// server-theme cache (which plugin sync rewrites). Saved themes are kept in
/// [ThemeRegistry]'s store bucket so server syncs never clear them.
class ThemeStoreService {
  ThemeStoreService(this._storagePaths);

  final StoragePathService _storagePaths;

  static const String _baseUrl =
      'https://raw.githubusercontent.com/Moonfin-Client/Themes/main/';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.plain,
    ),
  );

  Future<List<ThemeStoreCatalogEntry>> fetchCatalog() async {
    final response = await _dio.get<String>('${_baseUrl}index.json');
    final decoded = jsonDecode(response.data ?? '{}');
    final themes = decoded is Map ? decoded['themes'] : null;
    if (themes is! List) return const [];
    return themes
        .whereType<Map>()
        .map(
          (entry) => ThemeStoreCatalogEntry(
            id: entry['id']?.toString() ?? '',
            displayName:
                entry['displayName']?.toString() ?? entry['id']?.toString() ?? '',
            description: entry['description']?.toString(),
            file: entry['file']?.toString() ?? '',
          ),
        )
        .where((e) => e.id.isNotEmpty && e.file.isNotEmpty)
        .toList();
  }

  /// Fetches and validates a theme. Throws [ThemeSpecParseException] on a
  /// malformed theme.
  Future<ThemeSpec> fetchThemeSpec(String file) async {
    final response = await _dio.get<String>('$_baseUrl$file');
    final decoded = jsonDecode(response.data ?? '');
    return ThemeSpec.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<Directory> _storeDir() async {
    final root = await _storagePaths.getThemeCacheDir();
    final dir = Directory('${root.path}/_store');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileStem(String id) =>
      id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');

  /// Loads persisted store themes from disk and registers them. Call once at
  /// startup, before the active theme is resolved.
  Future<void> loadAndRegister() async {
    try {
      final dir = await _storeDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'));
      for (final file in files) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! Map) continue;
          final spec = ThemeSpec.fromJson(Map<String, dynamic>.from(decoded));
          if (ThemeRegistry.builtInIds.contains(spec.id)) continue;
          ThemeRegistry.registerStoreTheme(spec);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> saveStoreTheme(ThemeSpec spec) async {
    final dir = await _storeDir();
    final file = File('${dir.path}/${_fileStem(spec.id)}.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(spec.toJson()),
    );
    ThemeRegistry.registerStoreTheme(spec);
  }

  Future<void> deleteStoreTheme(String id) async {
    final dir = await _storeDir();
    final file = File('${dir.path}/${_fileStem(id)}.json');
    if (await file.exists()) {
      await file.delete();
    }
    ThemeRegistry.removeStoreTheme(id);
  }

  Set<String> savedStoreThemeIds() =>
      ThemeRegistry.storeThemes.map((s) => s.id).toSet();
}
