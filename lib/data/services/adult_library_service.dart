import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;
import 'package:moonfin/util/app_l10n.dart';

/// Shows or hides the adult library (the one named "XXX") for the signed-in
/// Jellyfin user.
///
/// Hiding happens on the server, through the user's library access, so the
/// library disappears everywhere at once: library list, home rows, latest,
/// search, continue watching — on every device using this account. Turning
/// it back on is guarded by a PIN of its own, separate from the login PIN.
class AdultLibraryService {
  /// Whether the adult library is shown for the signed-in user, as last
  /// checked or set; the menu's XXX search button follows it.
  static final visible = ValueNotifier<bool>(false);

  /// "XXX" in the private build; the installer's plugin names it "Adult".
  static final _namePattern = RegExp(r'^\s*(x{3}|adult)\s*$', caseSensitive: false);

  final PreferenceStore _store;
  final Dio? _dioOverride;

  AdultLibraryService({PreferenceStore? store, @visibleForTesting Dio? dio})
      : _store = store ?? GetIt.instance<PreferenceStore>(),
        _dioOverride = dio;

  MediaServerClient get _client => GetIt.instance<MediaServerClient>();

  String get _userId => _client.userId ?? '';
  String get _pinKey => 'adult_library_pin_hash_$_userId';

  // ---------------------------------------------------------------- PIN

  bool get hasPin => (_store.getString(_pinKey) ?? '').isNotEmpty;

  bool verifyPin(String pin) =>
      _store.getString(_pinKey) == sha256.convert(utf8.encode(pin)).toString();

  Future<void> setPin(String pin) =>
      _store.setString(_pinKey, sha256.convert(utf8.encode(pin)).toString());

  // ------------------------------------------------------------- server

  Dio get _dio =>
      _dioOverride ??
      Dio(BaseOptions(
        baseUrl: _client.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true,
        // Jellyfin 12 only accepts this header form.
        headers: {'Authorization': 'MediaBrowser Token="${_client.accessToken}"'},
      ));

  /// All libraries as (id, name); the adult one is matched by name.
  Future<List<({String id, String name})>> _libraries(Dio dio) async {
    final res = await dio.get('/Library/VirtualFolders');
    if (res.statusCode != 200 || res.data is! List) {
      throw Exception(appL10n().tgNoLibraryList('${res.statusCode}'));
    }
    return [
      for (final f in (res.data as List).whereType<Map>())
        if (f['ItemId'] is String)
          (id: f['ItemId'] as String, name: f['Name'] as String? ?? ''),
    ];
  }

  @visibleForTesting
  static String? adultLibraryId(List<({String id, String name})> libraries) {
    for (final l in libraries) {
      if (_namePattern.hasMatch(l.name)) return l.id;
    }
    return null;
  }

  Future<Map<String, dynamic>> _policy(Dio dio) async {
    final res = await dio.get('/Users/$_userId');
    final policy = res.data is Map ? res.data['Policy'] : null;
    if (res.statusCode != 200 || policy is! Map) {
      throw Exception(appL10n().tgNoUserSettings('${res.statusCode}'));
    }
    return Map<String, dynamic>.from(policy);
  }

  /// Null when there is no library called XXX.
  Future<bool?> isVisible() async {
    final dio = _dio;
    final id = adultLibraryId(await _libraries(dio));
    if (id == null) {
      visible.value = false;
      return null;
    }
    final shown = visibleIn(await _policy(dio), id);
    visible.value = shown;
    return shown;
  }

  @visibleForTesting
  static bool visibleIn(Map<String, dynamic> policy, String libraryId) {
    if (policy['EnableAllFolders'] == true) return true;
    final enabled = policy['EnabledFolders'];
    return enabled is List && enabled.contains(libraryId);
  }

  /// The policy that shows or hides [libraryId] and leaves everything else
  /// as it was. Hiding lists every other library explicitly; showing goes
  /// back to "all libraries" when that is what the user had apart from XXX.
  @visibleForTesting
  static Map<String, dynamic> withVisibility(
    Map<String, dynamic> policy,
    List<String> allLibraryIds,
    String libraryId, {
    required bool visible,
  }) {
    final next = Map<String, dynamic>.from(policy);
    final current = policy['EnableAllFolders'] == true
        ? allLibraryIds.toSet()
        : {...?(policy['EnabledFolders'] as List?)?.whereType<String>()};
    if (visible) {
      current.add(libraryId);
    } else {
      current.remove(libraryId);
    }
    final everything = allLibraryIds.every(current.contains);
    next['EnableAllFolders'] = everything;
    next['EnabledFolders'] = everything ? <String>[] : current.toList();
    return next;
  }

  Future<void> setVisible(bool visible) async {
    final dio = _dio;
    final libraries = await _libraries(dio);
    final id = adultLibraryId(libraries);
    if (id == null) throw Exception(appL10n().tgNoXxxLibrary);
    final policy = withVisibility(
      await _policy(dio),
      [for (final l in libraries) l.id],
      id,
      visible: visible,
    );
    final res = await dio.post('/Users/$_userId/Policy', data: policy);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(appL10n().tgJellyfinRejectedChange('${res.statusCode}'));
    }
    AdultLibraryService.visible.value = visible;
  }
}
