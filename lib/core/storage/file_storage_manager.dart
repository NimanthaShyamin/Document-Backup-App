import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/drive_constants.dart';
import '../errors/exceptions.dart';
import '../utils/crypto_utils.dart';

/// Manages sandboxed application storage for document files and staging buffers.
class FileStorageManager {
  FileStorageManager();

  Directory? _vaultDirectory;

  /// Returns the sandboxed base vault directory (`app_vault`).
  Future<Directory> getVaultDirectory() async {
    if (_vaultDirectory != null) return _vaultDirectory!;

    final baseDir = await getApplicationSupportDirectory();
    final vaultPath = p.join(baseDir.path, DriveConstants.vaultDirectory);
    final dir = Directory(vaultPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _vaultDirectory = dir;
    return dir;
  }

  /// Generates a sandboxed path for an isolated document based on its UUIDv4.
  Future<String> generatePath(String documentId, String fileExtension) async {
    final vault = await getVaultDirectory();
    final docDir = Directory(p.join(vault.path, DriveConstants.documentsSubdirectory, documentId));
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    final sanitizedExt = fileExtension.replaceAll('.', '').toLowerCase();
    return p.join(docDir.path, '$documentId.$sanitizedExt');
  }

  /// Copies an external source file into the protected application vault, computing its SHA-256.
  Future<({String localFilePath, String checksumSha256})> ingestFile({
    required String documentId,
    required File sourceFile,
  }) async {
    if (!await sourceFile.exists()) {
      throw StorageVaultException('Source file does not exist at ${sourceFile.path}');
    }

    final ext = p.extension(sourceFile.path);
    final targetPath = await generatePath(documentId, ext);
    final targetFile = await sourceFile.copy(targetPath);

    final checksum = await CryptoUtils.computeSha256(targetFile);
    return (localFilePath: targetFile.path, checksumSha256: checksum);
  }

  /// Deletes an isolated document directory and all its associated versions/staging files.
  Future<void> deleteDocumentFolder(String documentId) async {
    final vault = await getVaultDirectory();
    final docDir = Directory(p.join(vault.path, DriveConstants.documentsSubdirectory, documentId));
    if (await docDir.exists()) {
      await docDir.delete(recursive: true);
    }
  }
}
