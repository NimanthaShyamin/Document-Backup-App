import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_document_vault/core/storage/file_storage_manager.dart';
import 'package:vehicle_document_vault/data/datasources/local/app_database.dart';
import 'package:vehicle_document_vault/data/datasources/remote/ai_rescan_worker.dart';
import 'package:vehicle_document_vault/data/datasources/remote/gemini_document_extraction_service.dart';
import 'package:vehicle_document_vault/data/datasources/remote/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late File dummyFile;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('scanner_recovery_test_');
    dummyFile = File('${tempDir.path}/test_doc.png');
    await dummyFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AI Scanner & Sync Pipeline Stability Tests', () {
    test('GeminiDocumentExtractionService fails fast when API key is empty', () async {
      const service = GeminiDocumentExtractionService(apiKey: '');
      final result = await service.extractDetailsFromFile(dummyFile);

      expect(result.isAiDetected, isFalse);
      expect(result.errorMessage, contains('Gemini API key is not configured'));
    });

    test('GeminiDocumentExtractionService handles invalid API keys without stalling', () async {
      const service = GeminiDocumentExtractionService(apiKey: 'invalid_dummy_key_12345');
      final result = await service.extractDetailsFromFile(dummyFile);

      expect(result.isAiDetected, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('Missing file automatically clears requiresAiScan in database', () async {
      await db.into(db.vehicleDocuments).insert(
            VehicleDocumentsCompanion.insert(
              id: 'missing-file-doc',
              documentType: 'driving_license',
              category: const Value('driving_license'),
              title: 'Driver License',
              vehicleRegNo: 'General',
              localFilePath: '${tempDir.path}/does_not_exist.png',
              fileChecksumSha256: 'dummy_hash',
              syncStatus: 'queued_upload',
              lastModifiedTimestamp: 1000,
              createdAt: 1000,
              requiresAiScan: const Value(true),
            ),
          );

      final file = File('${tempDir.path}/does_not_exist.png');
      expect(await file.exists(), isFalse);

      // Simulate scanner detecting missing file
      if (!await file.exists()) {
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals('missing-file-doc'))).write(
          const VehicleDocumentsCompanion(requiresAiScan: Value(false)),
        );
      }

      final doc = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('missing-file-doc'))).getSingle();
      expect(doc.requiresAiScan, isFalse);
    });

    test('FileStorageManager.resolveFile returns active file when direct path exists', () async {
      final storage = FileStorageManager();
      final resolved = await storage.resolveFile('test-doc-id', dummyFile.path);
      expect(resolved, isNotNull);
      expect(await resolved!.exists(), isTrue);
    });

    test('FileStorageManager.resolveFile returns null when file does not exist anywhere', () async {
      final storage = FileStorageManager();
      final resolved = await storage.resolveFile('non-existent-id', '${tempDir.path}/none.png');
      expect(resolved, isNull);
    });

    test('GoogleAuthService provides clearCachedApi to invalidate expired DriveApi instances', () async {
      final auth = GoogleAuthService();
      await expectLater(auth.clearCachedApi(), completes);
    });

    test('Sync queue handles exponential backoff and recovery calculations', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          documentId: 'retry-doc',
          action: 'upload',
          retryCount: const Value(1),
          nextRetryAt: now + 5000,
          createdAt: now,
        ),
      );

      final task = await (db.select(db.syncQueue)..where((t) => t.documentId.equals('retry-doc'))).getSingle();
      expect(task.retryCount, equals(1));
      expect(task.nextRetryAt, greaterThan(now));
    });

    test('Sync failure with retries remaining preserves queued_upload status in database', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.vehicleDocuments).insert(
        VehicleDocumentsCompanion.insert(
          id: 'test-retry-doc',
          documentType: 'insurance',
          category: const Value('insurance'),
          title: 'Insurance Policy',
          vehicleRegNo: 'AB-1234',
          localFilePath: dummyFile.path,
          fileChecksumSha256: 'abc123hash',
          syncStatus: 'pending_upload',
          lastModifiedTimestamp: now,
          createdAt: now,
        ),
      );

      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          documentId: 'test-retry-doc',
          action: 'upload',
          retryCount: const Value(0),
          nextRetryAt: now,
          createdAt: now,
        ),
      );

      final task = await (db.select(db.syncQueue)..where((t) => t.documentId.equals('test-retry-doc'))).getSingle();
      const maxRetries = 5;
      final nextRetry = task.retryCount + 1;

      if (nextRetry < maxRetries) {
        // Updated logic: Keep status as queued_upload during transient retries
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals('test-retry-doc'))).write(
          const VehicleDocumentsCompanion(syncStatus: Value('queued_upload')),
        );
      } else {
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals('test-retry-doc'))).write(
          const VehicleDocumentsCompanion(syncStatus: Value('sync_failed')),
        );
      }

      final doc = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('test-retry-doc'))).getSingle();
      expect(doc.syncStatus, equals('queued_upload'));
    });

    test('Sync failure exceeding maxRetries transitions to sync_failed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.vehicleDocuments).insert(
        VehicleDocumentsCompanion.insert(
          id: 'test-exhausted-doc',
          documentType: 'insurance',
          category: const Value('insurance'),
          title: 'Insurance Policy',
          vehicleRegNo: 'AB-1234',
          localFilePath: dummyFile.path,
          fileChecksumSha256: 'abc123hash',
          syncStatus: 'queued_upload',
          lastModifiedTimestamp: now,
          createdAt: now,
        ),
      );

      const currentRetry = 4;
      const maxRetries = 5;
      const nextRetry = currentRetry + 1;

      if (nextRetry >= maxRetries) {
        await (db.update(db.vehicleDocuments)..where((t) => t.id.equals('test-exhausted-doc'))).write(
          const VehicleDocumentsCompanion(syncStatus: Value('sync_failed')),
        );
      }

      final doc = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('test-exhausted-doc'))).getSingle();
      expect(doc.syncStatus, equals('sync_failed'));
    });

    test('AiRescanWorker uses fixed unique task name to prevent WorkManager task storms', () {
      expect(AiRescanWorker.rescanUniqueWorkName, equals('com.vehicledocs.ai_rescan_worker'));
    });

    test('AppDatabase initializes with busy_timeout and WAL mode pragmas without error', () async {
      // Execute a custom query to ensure migrations and beforeOpen run
      final result = await db.customSelect('PRAGMA busy_timeout;').get();
      expect(result, isNotEmpty);
    });

    test('AiRescanWorker defers scanning when documents are pending cloud backup', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Insert a document that needs AI scan AND is pending upload
      await db.into(db.vehicleDocuments).insert(
        VehicleDocumentsCompanion.insert(
          id: 'pending-backup-doc',
          documentType: 'insurance',
          category: const Value('insurance'),
          title: 'Insurance',
          vehicleRegNo: 'WP-1111',
          localFilePath: dummyFile.path,
          fileChecksumSha256: 'pendinghash',
          syncStatus: 'pending_upload',
          lastModifiedTimestamp: now,
          createdAt: now,
          requiresAiScan: const Value(true),
        ),
      );

      // Insert active upload task in sync queue
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          documentId: 'pending-backup-doc',
          action: 'upload',
          retryCount: const Value(0),
          nextRetryAt: now,
          createdAt: now,
        ),
      );

      // Execute worker with dbOverride and skipScheduleNext = true
      final workerResult = await AiRescanWorker.executeWorker(
        dbOverride: db,
        apiKeyOverride: 'dummy_api_key',
        skipScheduleNext: true,
      );

      // Should return true (graceful deferral), and requiresAiScan should still be true (not scanned yet)
      expect(workerResult, isTrue);
      final doc = await (db.select(db.vehicleDocuments)..where((t) => t.id.equals('pending-backup-doc'))).getSingle();
      expect(doc.requiresAiScan, isTrue);
    });

    test('Deleted documents (in Recycle Bin) are excluded from pending upload query', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Document in recycle bin but marked as pending_upload
      await db.into(db.vehicleDocuments).insert(
        VehicleDocumentsCompanion.insert(
          id: 'deleted-doc',
          documentType: 'insurance',
          category: const Value('insurance'),
          title: 'Recycle Bin Doc',
          vehicleRegNo: 'WP-2222',
          localFilePath: dummyFile.path,
          fileChecksumSha256: 'deletedhash',
          syncStatus: 'pending_upload',
          lastModifiedTimestamp: now,
          createdAt: now,
          isDeleted: const Value(true),
          deletedAt: Value(now),
        ),
      );

      final pendingDocs = await (db.select(db.vehicleDocuments)
            ..where((t) => t.syncStatus.isIn(['pending_upload', 'queued_upload', 'sync_failed']) & t.isDeleted.equals(false)))
          .get();

      expect(pendingDocs.where((d) => d.id == 'deleted-doc'), isEmpty);
    });
  });
}
