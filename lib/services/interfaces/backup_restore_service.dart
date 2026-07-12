/// Service for exporting and importing application data.
abstract class BackupRestoreService {
  /// Exports all application data (settings, routines, sessions) to a JSON string.
  Future<String> exportData();

  /// Validates and imports data from a JSON string.
  /// Throws an exception if the data is invalid or corrupted.
  Future<void> importData(String jsonString);

  /// Helper to trigger the system file picker to save the backup file.
  Future<bool> saveBackupToFile();

  /// Helper to trigger the system file picker to read a backup file.
  Future<bool> restoreFromFile();
}
