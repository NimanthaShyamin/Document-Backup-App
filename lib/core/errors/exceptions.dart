/// Base exception class for the application.
abstract class AppException implements Exception {
  final String message;
  final dynamic details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => '$runtimeType: $message${details != null ? ' ($details)' : ''}';
}

/// Authentication failure with Google Sign-In or OAuth2 tokens.
class DriveAuthException extends AppException {
  const DriveAuthException(super.message, [super.details]);
}

/// Generic Google Drive API failure during upload, download, or file listing.
class DriveSyncException extends AppException {
  const DriveSyncException(super.message, [super.details]);
}

/// Integrity error when downloaded file SHA-256 does not match cloud metadata.
class ChecksumMismatchException extends AppException {
  const ChecksumMismatchException(super.message, [super.details]);
}

/// Local file system vault storage error.
class StorageVaultException extends AppException {
  const StorageVaultException(super.message, [super.details]);
}

/// Local database query or transaction error.
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.details]);
}
