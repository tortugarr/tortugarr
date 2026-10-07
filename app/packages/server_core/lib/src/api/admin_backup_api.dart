abstract class AdminBackupApi {
  Future<List<Map<String, dynamic>>> getBackups();
  /// Creates a backup. [options] is a BackupOptionsDto selecting what to
  /// include (e.g. `Metadata`, `Subtitles`, `Trickplay`); null uses defaults.
  Future<Map<String, dynamic>> createBackup([Map<String, dynamic>? options]);
  Future<void> restoreBackup(String backupPath);
  Future<Map<String, dynamic>> getBackupManifest(String backupPath);
}
