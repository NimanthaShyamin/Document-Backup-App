import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/drive_constants.dart';
import '../errors/exceptions.dart';
import '../utils/crypto_utils.dart';

/// Manages sandboxed application storage for document files and staging buffers.
class FileStorageManager {
  final Directory? _baseDirectoryOverride;

  FileStorageManager({Directory? baseDirectory}) : _baseDirectoryOverride = baseDirectory;

  Directory? _vaultDirectory;

  /// Returns the sandboxed base vault directory (`app_vault`).
  Future<Directory> getVaultDirectory() async {
    if (_vaultDirectory != null) return _vaultDirectory!;

    if (_baseDirectoryOverride != null) {
      _vaultDirectory = _baseDirectoryOverride;
      if (!await _vaultDirectory!.exists()) {
        await _vaultDirectory!.create(recursive: true);
      }
      return _vaultDirectory!;
    }

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

  /// Resolves the actual physical file for a document, handling OS sandbox directory relocations.
  Future<File?> resolveFile(String documentId, String localFilePath) async {
    // 1. Direct check on current path
    final directFile = File(localFilePath);
    if (await directFile.exists()) {
      return directFile;
    }

    // 2. Relative check within current vault directory
    final vault = await getVaultDirectory();
    final docDir = Directory(p.join(vault.path, DriveConstants.documentsSubdirectory, documentId));
    if (await docDir.exists()) {
      final entities = await docDir.list().toList();
      for (final entity in entities) {
        if (entity is File && await entity.exists()) {
          return entity;
        }
      }
    }

    return null;
  }
}
