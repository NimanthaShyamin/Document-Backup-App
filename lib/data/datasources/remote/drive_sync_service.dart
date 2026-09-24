import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../../core/constants/drive_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/remote_document_metadata.dart';
import 'google_auth_service.dart';

/// Repository service interacting strictly with the private, hidden Google Drive AppData folder (`appDataFolder`).
/// Guarantees that personal vehicle documents are isolated, secure, and immune from accidental user deletion in Drive UI.
class DriveSyncService {
  final GoogleAuthService _authService;

  DriveSyncService({GoogleAuthService? authService})
      : _authService = authService ?? GoogleAuthService();

  GoogleAuthService get authService => _authService;

  /// Helper to get an active DriveApi instance from the GoogleAuthService.
  Future<drive.DriveApi> _getDriveApi({bool promptIfUnauthenticated = true}) =>
      _authService.getDriveApi(promptIfUnauthenticated: promptIfUnauthenticated);

  /// Executes a Drive API call with automatic 401 retry (re-authenticating on token expiration).
  Future<T> _executeWithRetry<T>(Future<T> Function(drive.DriveApi api) action) async {
    try {
      final api = await _getDriveApi();
      return await action(api);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 401) {
        developer.log('Received 401 Unauthorized from Drive API. Attempting silent re-auth...');
        await _authService.signInSilently(reAuthenticate: true);
        final freshApi = await _getDriveApi();
        return await action(freshApi);
      }
      developer.log('Drive API error (${e.status}): ${e.message}', error: e);
      throw DriveSyncException('Drive API error [${e.status}]: ${e.message}', e);
    } on SocketException catch (e) {
      developer.log('Network connectivity lost during Drive operation: $e');
      throw DriveSyncException('Network connectivity lost: ${e.message}', e);
    } on http.ClientException catch (e) {
      developer.log('HTTP Client exception during Drive operation: $e');
      throw DriveSyncException('HTTP connection failure: ${e.message}', e);
    } catch (e, stack) {
      if (e is AppException) rethrow;
      developer.log('Unexpected error during Drive operation', error: e, stackTrace: stack);
      throw DriveSyncException('Drive operation failed: $e', e);
    }
  }

  /// Resolves the standard MIME type for document extensions.
  String _resolveMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'json':
        return 'application/json';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// **Upload File:**
  /// Uploads a raw local file (image or PDF) directly into the hidden `appDataFolder` without prompting the user.
  /// Attaches custom domain properties to `appProperties`. If a file with the same name already exists in
  /// `appDataFolder`, updates the existing remote file instead of creating duplicate records.
  Future<String> uploadFile({
    required File localFile,
    required String documentId,
    required String documentType,
    required String vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    required String checksumSha256,
    required DateTime lastModifiedTimestamp,
    String? customMimeType,
  }) async {
    if (!await localFile.exists()) {
      throw FileSystemException('Local file does not exist for upload: ${localFile.path}');
    }

    final fileLength = await localFile.length();
    final fileExtension = localFile.path.split('.').last.toLowerCase();
    final fileName = '$documentId.$fileExtension';
    final mimeType = customMimeType ?? _resolveMimeType(localFile.path);

    final appProperties = <String, String>{
      'document_id': documentId,
      'document_type': documentType,
      'vehicle_reg_no': vehicleRegNo,
      'policy_no': policyNo ?? '',
      'expiry_date': expiryDate?.millisecondsSinceEpoch.toString() ?? '',
      'checksum_sha256': checksumSha256,
      'client_modified': lastModifiedTimestamp.millisecondsSinceEpoch.toString(),
    };

    return _executeWithRetry((driveApi) async {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [DriveConstants.appDataSpace]
        ..appProperties = appProperties;

      final mediaStream = drive.Media(
        localFile.openRead(),
        fileLength,
        contentType: mimeType,
      );

      // Query to check if the file already exists in AppData
      final existingFiles = await driveApi.files.list(
        spaces: DriveConstants.appDataSpace,
        q: "'${DriveConstants.appDataSpace}' in parents and trashed = false and name = '$fileName'",
        $fields: 'files(id, name)',
      );

      drive.File uploadedFile;
      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        final existingId = existingFiles.files!.first.id!;
        developer.log('Existing remote file found ($existingId). Updating in-place...');
        uploadedFile = await driveApi.files.update(
          driveFile,
          existingId,
          uploadMedia: mediaStream,
        );
        developer.log('Updated existing AppData file: $existingId');
      } else {
        developer.log('No existing file found. Creating new AppData file: $fileName');
        uploadedFile = await driveApi.files.create(
          driveFile,
          uploadMedia: mediaStream,
        );
        developer.log('Created new AppData file: ${uploadedFile.id}');
      }

      if (uploadedFile.id == null) {
        throw const DriveSyncException('Google Drive returned a null file ID after upload.');
      }

      return uploadedFile.id!;
    });
  }

  /// **List Cloud Backups:**
  /// Queries all files residing in `appDataFolder` using the query `'appDataFolder' in parents and trashed = false`.
  /// Handles pagination across all pages and parses domain metadata.
  Future<List<RemoteDocumentMetadata>> listCloudBackups() async {
    return _executeWithRetry((driveApi) async {
      final List<RemoteDocumentMetadata> results = [];
      String? pageToken;

      do {
        final fileList = await driveApi.files.list(
          spaces: DriveConstants.appDataSpace,
          q: "'${DriveConstants.appDataSpace}' in parents and trashed = false",
          $fields:
              'nextPageToken, files(id, name, mimeType, modifiedTime, md5Checksum, appProperties, trashed, size)',
          pageToken: pageToken,
          pageSize: 100,
        );

        if (fileList.files != null) {
          for (final f in fileList.files!) {
            if (f.trashed == true || f.id == null) continue;

            final metadata = RemoteDocumentMetadata.fromDriveFile(f);
            if (metadata != null) {
              results.add(metadata);
            }
          }
        }
        pageToken = fileList.nextPageToken;
      } while (pageToken != null);

      return results;
    });
  }

  /// **Download File:**
  /// Downloads a remote file from `appDataFolder` by fileId directly to a local target file.
  /// Computes and verifies the downloaded file's SHA-256 against expected checksum.
  Future<File> downloadFile({
    required String fileId,
    required File targetFile,
    required String expectedSha256,
  }) async {
    return _executeWithRetry((driveApi) async {
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final sink = targetFile.openWrite();
      try {
        await media.stream.pipe(sink);
      } finally {
        await sink.flush();
        await sink.close();
      }

      // Verify SHA-256 checksum integrity
      final computedSha256 = (await sha256.bind(targetFile.openRead()).first).toString();
      if (computedSha256 != expectedSha256) {
        await targetFile.delete();
        throw ChecksumMismatchException(
          'Corrupted cloud file download for $fileId. Expected $expectedSha256, got $computedSha256',
        );
      }

      return targetFile;
    });
  }

  /// **Delete Remote File:**
  /// Permanently removes a file from `appDataFolder` by its Google Drive File ID.
  Future<void> deleteRemoteFile(String driveFileId) async {
    return _executeWithRetry((driveApi) async {
      try {
        await driveApi.files.delete(driveFileId);
        developer.log('Successfully deleted remote Drive AppData file: $driveFileId');
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status == 404) {
          developer.log('Remote file already deleted or not found: $driveFileId');
          return;
        }
        rethrow;
      }
    });
  }
}
