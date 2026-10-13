/// Uploads client-side diagnostic logs to the media server as a report.
///
/// Backed by Jellyfin's `POST /ClientLog/Document` endpoint. Servers that do
/// not support it (Emby, or Jellyfin with client log upload disabled) expose a
/// null `clientLogApi`, so callers must null-check before use.
abstract class ClientLogApi {
  /// Uploads [content] as a plain-text log document.
  ///
  /// Returns the server-assigned file name on success, or null when the server
  /// accepted the request but reported no file name.
  Future<String?> uploadDocument(String content);
}
