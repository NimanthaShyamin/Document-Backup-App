import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../../../core/constants/drive_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/remote_document_metadata.dart';

/// Authenticated HTTP Client forwarding GoogleSignIn OAuth2 Bearer token headers.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

/// Service handling file synchronization strictly within the private Google Drive AppData space.
class DriveAppDataService {
  final GoogleSignIn _googleSignIn;
  drive.DriveApi? _driveApi;

  DriveAppDataService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                DriveConstants.appDataScope, // 'https://www.googleapis.com/auth/drive.appdata'
              ],
            );

  /// Authenticates silently with Google and initializes the DriveApi client.
  Future<drive.DriveApi> _ensureAuthenticated() async {
    if (_driveApi != null) return _driveApi!;

    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        throw const DriveAuthException('User canceled Google Drive authentication.');
      }

      final authHeaders = await account.authHeaders;
      final authClient = _GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(authClient);
      return _driveApi!;
    } catch (e, stack) {
      developer.log('Google Drive Authentication Failed', error: e, stackTrace: stack);
      throw DriveAuthException('Failed to authenticate with Google Drive AppData: $e');
    }
  }

  /// Lists all documents present in the private `appDataFolder`.
  Future<List<RemoteDocumentMetadata>> listAppDataFiles() async {
    final driveApi = await _ensureAuthenticated();
    final List<RemoteDocumentMetadata> results = [];
    String? pageToken;

    try {
      do {
        final fileList = await driveApi.files.list(
          spaces: DriveConstants.appDataSpace, // 'appDataFolder'
          fields: 'nextPageToken, files(id, name, modifiedTime, md5Checksum, appProperties, trashed, size)',
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
    } catch (e, stack) {
      developer.log('Error listing AppData files', error: e, stackTrace: stack);
      throw DriveSyncException('Failed to list files from Google Drive AppData: $e');
    }
  }

  /// Uploads or updates a document file in the `appDataFolder` with embedded `appProperties`.
  Future<String> uploadDocumentFile({
    required File localFile,
    required String documentId,
    required String documentType,
    required String vehicleRegNo,
    String? policyNo,
    DateTime? expiryDate,
    required String checksumSha256,
    required DateTime lastModifiedTimestamp,
  }) async {
    final driveApi = await _ensureAuthenticated();

    if (!await localFile.exists()) {
      throw FileSystemException('Local file does not exist for upload', localFile.path);
    }

    final fileLength = await localFile.length();
    final fileName = '$documentId.${localFile.path.split('.').last}';

    final appProperties = {
      'document_id': documentId,
      'document_type': documentType,
      'vehicle_reg_no': vehicleRegNo,
      'policy_no': policyNo ?? '',
      'expiry_date': expiryDate?.millisecondsSinceEpoch.toString() ?? '',
      'checksum_sha256': checksumSha256,
      'client_modified': lastModifiedTimestamp.millisecondsSinceEpoch.toString(),
    };

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [DriveConstants.appDataSpace]
      ..appProperties = appProperties;

    final mediaStream = drive.Media(
      localFile.openRead(),
      fileLength,
    );

    try {
      // 1. Check if the file already exists in AppData to perform an update instead of creating duplicates
      final existingFiles = await driveApi.files.list(
        spaces: DriveConstants.appDataSpace,
        q: "name = '$fileName' and trashed = false",
        fields: 'files(id)',
      );

      drive.File uploadedFile;
      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        final existingId = existingFiles.files!.first.id!;
        uploadedFile = await driveApi.files.update(
          driveFile,
          existingId,
          uploadMedia: mediaStream,
        );
        developer.log('Updated existing AppData file: $existingId');
      } else {
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
    } catch (e, stack) {
      developer.log('Failed to upload document to AppData', error: e, stackTrace: stack);
      throw DriveSyncException('Upload failed for document $documentId: $e');
    }
  }

  /// Downloads a remote file by Drive File ID to a specified sandboxed target path with SHA-256 verification.
  Future<File> downloadDocumentFile({
    required String driveFileId,
    required File targetFile,
    required String expectedSha256,
  }) async {
    final driveApi = await _ensureAuthenticated();

    // Staging path to prevent corrupted writes in the primary vault
    final stagingFile = File('${targetFile.path}.tmp');
    if (await stagingFile.exists()) {
      await stagingFile.delete();
    }
    await stagingFile.create(recursive: true);

    try {
      final drive.Media media = await driveApi.files.get(
        driveFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final sink = stagingFile.openWrite();
      await media.stream.pipe(sink);
      await sink.flush();
      await sink.close();

      // Verify SHA-256 integrity
      final bytes = await stagingFile.readAsBytes();
      final downloadedHash = sha256.convert(bytes).toString();

      if (expectedSha256.isNotEmpty &&
          downloadedHash.toLowerCase() != expectedSha256.toLowerCase()) {
        await stagingFile.delete();
        throw ChecksumMismatchException(
          'Downloaded file checksum $downloadedHash does not match expected $expectedSha256',
        );
      }

      // Atomically move to target
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await stagingFile.rename(targetFile.path);

      developer.log('Successfully downloaded and validated: ${targetFile.path}');
      return targetFile;
    } catch (e, stack) {
      if (await stagingFile.exists()) {
        await stagingFile.delete();
      }
      developer.log('Failed to download file $driveFileId', error: e, stackTrace: stack);
      throw DriveSyncException('Download failed for file $driveFileId: $e');
    }
  }

  /// Deletes a file from the hidden `appDataFolder`.
  Future<void> deleteDocumentFile(String driveFileId) async {
    final driveApi = await _ensureAuthenticated();
    try {
      await driveApi.files.delete(driveFileId);
      developer.log('Deleted AppData file: $driveFileId');
    } catch (e, stack) {
      developer.log('Failed to delete AppData file $driveFileId', error: e, stackTrace: stack);
      throw DriveSyncException('Deletion failed for $driveFileId: $e');
    }
  }
}
