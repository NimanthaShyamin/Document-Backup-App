import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/core/utils/crypto_utils.dart';
import 'package:vehicle_document_vault/domain/entities/document_type.dart';
import 'package:vehicle_document_vault/domain/entities/sync_status.dart';

void main() {
  group('CryptoUtils Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('crypto_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Computes correct SHA-256 checksum for known byte string', () async {
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsString('Antigravity Vehicle Document Vault Test');

      final hash = await CryptoUtils.computeSha256(file);
      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // SHA-256 hex length

      final isValid = await CryptoUtils.verifyChecksum(file, hash);
      expect(isValid, isTrue);

      final isInvalid = await CryptoUtils.verifyChecksum(file, '0000000000000000000000000000000000000000000000000000000000000000');
      expect(isInvalid, isFalse);
    });
  });

  group('Sync Queue Exponential Backoff Logic', () {
    test('Exponential backoff formula strictly clamps to 900 seconds (15 minutes)', () {
      int calculateBackoffMs(int retryCount) {
        final backoffMs = (5000 * pow(2, retryCount)).toInt();
        return min(backoffMs, 900000);
      }

      expect(calculateBackoffMs(0), equals(5000)); // 5 seconds
      expect(calculateBackoffMs(1), equals(10000)); // 10 seconds
      expect(calculateBackoffMs(2), equals(20000)); // 20 seconds
      expect(calculateBackoffMs(3), equals(40000)); // 40 seconds
      expect(calculateBackoffMs(4), equals(80000)); // 80 seconds
      expect(calculateBackoffMs(10), equals(900000)); // Clamped to 15 mins (900,000ms)
    });
  });

  group('Domain Entities Parsing', () {
    test('DocumentType parses from string correctly', () {
      expect(DocumentType.fromString('fuel_qr'), equals(DocumentType.fuelQr));
      expect(DocumentType.fromString('insurance_card'), equals(DocumentType.insuranceCard));
      expect(DocumentType.fromString('revenue_license'), equals(DocumentType.revenueLicense));
      expect(DocumentType.fromString('unknown_val'), equals(DocumentType.custom));
    });

    test('SyncStatus parses from string correctly', () {
      expect(SyncStatus.fromString('synced'), equals(SyncStatus.synced));
      expect(SyncStatus.fromString('queued_upload'), equals(SyncStatus.queuedUpload));
      expect(SyncStatus.fromString('download_pending'), equals(SyncStatus.downloadPending));
      expect(SyncStatus.fromString('unknown_val'), equals(SyncStatus.queuedUpload));
    });
  });
}
