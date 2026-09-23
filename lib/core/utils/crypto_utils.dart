import 'dart:io';
import 'package:crypto/crypto.dart';

/// Cryptographic utilities for file hashing and validation.
class CryptoUtils {
  const CryptoUtils._();

  /// Computes the hex-encoded SHA-256 hash of a local file.
  static Future<String> computeSha256(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Cannot compute SHA-256. File does not exist.', file.path);
    }
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Verifies file bytes against an expected SHA-256 hex string.
  static Future<bool> verifyChecksum(File file, String expectedSha256) async {
    final actual = await computeSha256(file);
    return actual.toLowerCase() == expectedSha256.toLowerCase();
  }
}
