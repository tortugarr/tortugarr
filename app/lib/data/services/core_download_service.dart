import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../util/game_cores.dart';

/// Downloads and installs libretro cores from the libretro buildbot on Android
/// and desktop. Cores are not bundled, so the user picks which systems to add
/// from the emulator cores settings screen.
class CoreDownloadService {
  CoreDownloadService(this._store, {Dio? dio}) : _dio = dio ?? Dio();

  final PreferenceStore _store;
  final Dio _dio;

  /// The core ids recorded as installed.
  List<String> get installed =>
      _store.getStringList(installedCoresPreferenceKey) ?? const <String>[];

  bool isInstalled(String coreId) => installed.contains(coreId);

  /// Whether libretro publishes a build of [coreId] for this platform and
  /// architecture. Rows for cores without a build are shown as unavailable.
  bool isAvailable(String coreId) => coreDownloadUrl(coreId) != null;

  /// Downloads [coreId], extracts the core file into [coresDirectory], and
  /// records it as installed. [onProgress] reports 0..1 while downloading.
  Future<void> download(
    String coreId, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url = coreDownloadUrl(coreId);
    if (url == null) {
      throw StateError('No core build for this platform');
    }

    final response = await _dio.get<List<int>>(
      url,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      },
    );
    final zipBytes = response.data;
    if (zipBytes == null || zipBytes.isEmpty) {
      throw StateError('Empty core download');
    }

    final coreBytes = _extractCore(zipBytes);
    if (coreBytes == null) {
      throw StateError('Core file missing from download');
    }

    final dir = await coresDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/${coreFileName(coreId)}');
    await file.writeAsBytes(coreBytes, flush: true);

    await _markInstalled(coreId, true);
  }

  /// Deletes the installed core file and forgets it.
  Future<void> remove(String coreId) async {
    final dir = await coresDirectory();
    final file = File('${dir.path}/${coreFileName(coreId)}');
    if (await file.exists()) await file.delete();
    await _markInstalled(coreId, false);
  }

  /// The single core binary inside a buildbot zip, whatever it is named.
  Uint8List? _extractCore(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.toLowerCase();
      if (name.endsWith('.so') ||
          name.endsWith('.dll') ||
          name.endsWith('.dylib')) {
        return entry.content;
      }
    }
    return null;
  }

  Future<void> _markInstalled(String coreId, bool value) async {
    final current = installed.toList();
    if (value) {
      if (!current.contains(coreId)) current.add(coreId);
    } else {
      current.remove(coreId);
    }
    await _store.setStringList(installedCoresPreferenceKey, current);
  }
}
