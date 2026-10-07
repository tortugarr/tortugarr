import 'prowlarr_search_client.dart';
import 'qbittorrent_client.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Adult releases skip Radarr (TMDB, and so Radarr, does not cover them):
/// they go straight to qBittorrent in the "xxx" category, which saves to the
/// XXX library folder. qBittorrent's on-finish hook asks Jellyfin to rescan.
class XxxDownloadService {
  static const category = 'xxx';

  /// Must match the "xxx" category's save path in qBittorrent.
  static const savePath = r'E:\-=XxX=-';

  Future<void> download(ProwlarrRelease release) async {
    final payload = await ProwlarrSearchClient().fetchPayload(release);
    final qb = QbittorrentClient();
    String? added;
    if (payload.magnet != null && payload.magnet!.isNotEmpty) {
      added = await qb.addMagnet(
        payload.magnet!,
        category: category,
        savePath: savePath,
      );
    } else if (payload.torrentBytes != null) {
      added = await qb.addTorrentFile(
        payload.torrentBytes!,
        filename: payload.fileName,
        category: category,
        savePath: savePath,
      );
    }
    if (added == null) {
      throw Exception(appL10n().tgXxxAddFailed(release.title));
    }
  }
}
