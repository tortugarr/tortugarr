import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Fetches the community theme catalog from the Moonfin Themes repo and keeps
/// saved themes apart from the server themes that plugin sync rewrites.
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

  // Saved themes live in preferences because tvOS clears the offline root on
  // updates, and the root moves when the download location changes.
  static const _prefsKey = 'theme_store_saved_themes';

  Map<String, dynamic> _readSaved(SharedPreferences prefs) {
    try {
      final decoded = jsonDecode(prefs.getString(_prefsKey) ?? '{}');
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  /// Moves themes that older builds saved as files into [saved] and deletes
  /// the files once that's written.
  Future<void> _migrateLegacyFiles(
    SharedPreferences prefs,
    Map<String, dynamic> saved,
  ) async {
    try {
      final root = await _storagePaths.getThemeCacheDir();
      final dir = Directory('${root.path}/_store');
      if (!await dir.exists()) return;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'));
      for (final file in files) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! Map) continue;
          final spec = ThemeSpec.fromJson(Map<String, dynamic>.from(decoded));
          saved.putIfAbsent(spec.id, spec.toJson);
        } catch (_) {}
      }
      if (await prefs.setString(_prefsKey, jsonEncode(saved))) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Loads saved store themes and registers them. Call once at startup,
  /// before the active theme is resolved.
  Future<void> loadAndRegister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _readSaved(prefs);
      await _migrateLegacyFiles(prefs, saved);
      for (final json in saved.values) {
        try {
          if (json is! Map) continue;
          final spec = ThemeSpec.fromJson(Map<String, dynamic>.from(json));
          if (ThemeRegistry.builtInIds.contains(spec.id)) continue;
          ThemeRegistry.registerStoreTheme(spec);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> saveStoreTheme(ThemeSpec spec) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _readSaved(prefs)..[spec.id] = spec.toJson();
    await prefs.setString(_prefsKey, jsonEncode(saved));
    ThemeRegistry.registerStoreTheme(spec);
  }

  Future<void> deleteStoreTheme(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _readSaved(prefs)..remove(id);
    await prefs.setString(_prefsKey, jsonEncode(saved));
    ThemeRegistry.removeStoreTheme(id);
  }

  Set<String> savedStoreThemeIds() =>
      ThemeRegistry.storeThemes.map((s) => s.id).toSet();
}
