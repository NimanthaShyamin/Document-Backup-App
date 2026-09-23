/// Constants for Google Drive AppData Synchronization
class DriveConstants {
  const DriveConstants._();

  /// Hidden, sandboxed application data folder scope.
  /// Files placed in this scope are invisible in drive.google.com and safe from accidental user deletion.
  static const String appDataScope = 'https://www.googleapis.com/auth/drive.appdata';

  /// The root alias for the hidden AppData folder in Google Drive API v3.
  static const String appDataSpace = 'appDataFolder';

  /// Vault storage directory name within the application sandbox.
  static const String vaultDirectory = 'app_vault';
  static const String documentsSubdirectory = 'documents';
  static const String stagingSubdirectory = 'staging';
  static const String cacheSubdirectory = 'cache';

  /// Sync retry parameters
  static const int maxSyncRetries = 5;
  static const int baseRetryDelaySeconds = 5;
  static const int maxRetryDelaySeconds = 900; // 15 minutes
}
